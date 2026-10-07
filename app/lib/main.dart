import 'package:flutter/material.dart';

import 'app/paperdrop_app.dart';
import 'legal/pdfium_notices.dart';

void main() {
  // The PDFium binary this application links is not covered by Flutter's own
  // notices (NFR-LIC-001): its licences ship as assets and are registered here,
  // before the first frame, so that Flutter's licence page shows them.
  registerPdfiumLicences();
  runApp(const PaperdropApp());
}
