// Точка входа тестов. Запускать через ./test.sh.

import Foundation

runTypoTests()
runMetricsAnchorTests()
runPrefsTests()
runDocumentTests()
runHighlighterTests()
runEditorTests()

exit(Check.report())
