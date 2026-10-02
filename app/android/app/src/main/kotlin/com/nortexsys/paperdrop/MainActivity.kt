package com.nortexsys.paperdrop

import com.nortexsys.paperdrop.pdftext.PdfBoxTextChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Candidate A of ADR-011 (close-adr-011-pdf-text-route, task 1.1): the
        // evaluation harness reads documents through this channel. It is
        // registered here and not in a plugin because it is not a product
        // feature yet — the winning candidate becomes an adapter behind
        // PdfTextSource after the product owner's decision of Tue 6 Oct.
        PdfBoxTextChannel.attach(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
    }
}
