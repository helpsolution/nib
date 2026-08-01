// Точка входа тестов. Запускать через ./test.sh.

import Foundation

runTypoTests()
runDocumentTests()
runHighlighterTests()

exit(Check.report())
