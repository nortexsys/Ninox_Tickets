# Rules of the release build of the Android application.

# Candidate A of ADR-011 (close-adr-011-pdf-text-route, design §1, task 1.5).
#
# PdfBox-Android's JPXFilter can decode JPEG 2000 images through the optional
# com.gemalto.jp2 codec. This project does not depend on that codec and never
# reaches it — the candidate reads the text layer and renders nothing — but R8
# refuses to complete a release build while a class referenced from the library
# is absent:
#
#   ERROR: R8: Missing class com.gemalto.jp2.JP2Decoder (referenced from:
#   com.tom_roush.pdfbox.filter.JPXFilter.readJPX(...))
#
# The reference is therefore declared expected. Nothing else is kept, removed or
# renamed by this rule, and the dependency it belongs to leaves with the
# candidate: if candidate B wins the decision of Tue 6 Oct, this rule leaves
# with candidate A's code and Gradle line (design §5).
-dontwarn com.gemalto.jp2.**
