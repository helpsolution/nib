// Точка входа тестов. Запускать через ./test.sh.

import Foundation

runTypoTests()
runMetricsAnchorTests()
runPrefsTests()
runDocumentTests()
runHighlighterTests()
runRendererTests()
runEditorTests()
// Последним: поднимает NSApplication и окно, остальным тестам это не нужно.
runSwapTests()

exit(Check.report())
