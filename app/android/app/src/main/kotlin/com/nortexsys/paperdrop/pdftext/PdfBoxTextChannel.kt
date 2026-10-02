package com.nortexsys.paperdrop.pdftext

import android.content.Context
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.pdmodel.PDPage
import com.tom_roush.pdfbox.pdmodel.common.PDRectangle
import com.tom_roush.pdfbox.text.PDFTextStripper
import com.tom_roush.pdfbox.text.TextPosition
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Candidate A of ADR-011 — **PdfBox-Android** — on the Android side.
 * (`close-adr-011-pdf-text-route`, design §1, task 1.1.)
 *
 * The library is a JVM library ported to Android and cannot run outside the
 * application process, so the reading happens here and the Dart side is a
 * method channel to this class. What it answers is design §2's shape: per page,
 * the words *PdfBox itself* segments, each with a box in PDF points and a
 * top-left origin.
 *
 * **The segmentation is the library's.** `PDFTextStripper` cuts a line into
 * words in its own `normalize`, and hands each one to `writeString` as a single
 * call (`writeLine` in `PDFTextStripper`: one `writeString` per word, a word
 * separator between them). Overriding `writeString` therefore takes PdfBox's own
 * words, and this class adds no rule of its own: it merges nothing and splits
 * nothing (design §2). The box is the extent of the word's own glyph run —
 * left edge, right edge, and the vertical extent between the baseline
 * (`yDirAdj`) and the top of the font box above it.
 *
 * **Read-only.** The document is opened with `PDDocument.load` and never saved,
 * re-flattened or re-compressed (ADR-015). The harness proves it by hashing the
 * file before and after the call, not by reading this class.
 */
class PdfBoxTextChannel private constructor(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        /** The channel the Dart side calls. It is also in `pdfbox_text_candidate.dart`. */
        const val CHANNEL_NAME = "com.nortexsys.paperdrop/pdf_text_pdfbox"

        /** The method that reads one document. */
        private const val METHOD_READ_WORDS = "readWords"

        /** The argument of [METHOD_READ_WORDS]: the path of the document to read. */
        private const val ARGUMENT_PATH = "path"

        /**
         * The library and version this build resolved, in design §2's `tool`
         * format. It is stated here, in `build.gradle.kts` and in the Dart
         * candidate, and the Dart side refuses a reply that names another
         * version: a stale APK must not be measured under the wrong name.
         */
        const val TOOL = "pdfbox-android 2.0.27.0"

        /** Registers the channel for an engine. Called once, from `MainActivity`. */
        fun attach(context: Context, messenger: BinaryMessenger) {
            MethodChannel(messenger, CHANNEL_NAME).setMethodCallHandler(PdfBoxTextChannel(context))
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != METHOD_READ_WORDS) {
            result.notImplemented()
            return
        }
        val path = call.argument<String>(ARGUMENT_PATH)
        if (path == null || path.isEmpty()) {
            result.error("bad_arguments", "$METHOD_READ_WORDS needs the $ARGUMENT_PATH argument", null)
            return
        }
        try {
            // PdfBox reads its AFM and glyph-list resources from the assets the
            // AAR ships; without this the first text extraction fails.
            PDFBoxResourceLoader.init(context)
            PDDocument.load(File(path)).use { document ->
                val collector = WordCollector()
                collector.getText(document)
                result.success(mapOf("tool" to TOOL, "pages" to collector.pages))
            }
        } catch (exception: Exception) {
            result.error("pdf_text_failed", exception.message ?: exception.javaClass.simpleName, null)
        }
    }

    /**
     * A `PDFTextStripper` that keeps the words instead of the text.
     *
     * The page size is taken from the page's crop box, swapped for the two
     * rotations that swap the axes, because `getXDirAdj`/`getYDirAdj` are
     * already rotation-adjusted and a word's distance from the top of the page
     * is only meaningful against the height of the box it was measured in.
     */
    private class WordCollector : PDFTextStripper() {
        val pages = mutableListOf<Map<String, Any>>()

        private var page: MutableMap<String, Any>? = null
        private var words = mutableListOf<Map<String, Any>>()

        override fun startPage(page: PDPage) {
            super.startPage(page)
            val box: PDRectangle = page.cropBox ?: page.mediaBox
            val rotation = ((page.rotation % 360) + 360) % 360
            val width = if (rotation == 90 || rotation == 270) box.height.toDouble() else box.width.toDouble()
            val height = if (rotation == 90 || rotation == 270) box.width.toDouble() else box.height.toDouble()
            words = mutableListOf()
            val record = hashMapOf<String, Any>(
                "index" to pages.size,
                "width" to width,
                "height" to height,
                "words" to words,
            )
            this.page = record
            pages.add(record)
        }

        override fun writeString(text: String, textPositions: List<TextPosition>) {
            if (page == null || text.isBlank() || textPositions.isEmpty()) {
                return
            }
            var x0 = Double.MAX_VALUE
            var x1 = -Double.MAX_VALUE
            var top = Double.MAX_VALUE
            var bottom = -Double.MAX_VALUE
            for (position in textPositions) {
                val left = position.xDirAdj.toDouble()
                val right = left + position.widthDirAdj.toDouble()
                // yDirAdj measures from the top of the page down to the baseline;
                // the font box sits above it, so the top of the box is the
                // smaller number and the baseline is the bottom of it.
                val baseline = position.yDirAdj.toDouble()
                val glyphTop = baseline - position.heightDir.toDouble()
                if (left < x0) x0 = left
                if (right > x1) x1 = right
                if (glyphTop < top) top = glyphTop
                if (baseline > bottom) bottom = baseline
            }
            words.add(
                hashMapOf<String, Any>(
                    "text" to text,
                    "x0" to x0,
                    "x1" to x1,
                    "top" to top,
                    "bottom" to bottom,
                ),
            )
        }
    }
}
