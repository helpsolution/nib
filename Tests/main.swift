// Точка входа тестов. Запускать через ./test.sh.

import Foundation

runTypoTests()
runPrefsTests()
runDocumentTests()
runHighlighterTests()
runEditorTests()

exit(Check.report())
