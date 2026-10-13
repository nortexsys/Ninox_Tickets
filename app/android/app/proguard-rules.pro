# R8 rules of the shipped application.
#
# `google_mlkit_text_recognition` builds its recognizer for five scripts, and
# four of them — Chinese, Devanagari, Japanese and Korean — are declared
# `compileOnly` in the plugin's own Gradle file: the plugin's
# `TextRecognizer.initialize` names their option classes, the artefacts that
# carry them do not ship in the application, and R8 therefore reports eight
# missing classes and refuses the release build.
#
# The application uses the **Latin** recognizer only (ES, EN, FR, DE, IT, PT:
# `MlKitTextRecognizer`), and a script recognizer this app never builds is
# deliberately absent — adding one would be shipping a model for a script the
# product does not read. These rules say so, one per class, exactly as the
# Android Gradle plugin generated them in
# `app/build/app/outputs/mapping/release/missing_rules.txt`; they are warnings to
# suppress, not classes to keep.
#
# If a non-Latin script ever enters scope, this is the file that says what was
# taken out and why, and the rule for that script leaves with its code.
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
