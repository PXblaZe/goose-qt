// Three misuses, one per run: misuse deleted|range|qtbug
package main

import (
	"fmt"
	"os"

	qt "github.com/mappu/miqt/qt6"
)

func main() {
	qt.NewQApplication(os.Args[:1])
	switch os.Args[1] {
	case "deleted":
		w := qt.NewQWidget2()
		l := qt.NewQLabel5("x", w)
		w.Delete()
		l.SetText("y")
	case "range":
		qt.NewQSpinBox2().SetValue(10000000000)
	case "qtbug":
		c := qt.NewQComboBox2()
		c.AddItem("a")
		c.SetView(c.View())
		c.ShowPopup()
		qt.QCoreApplication_ProcessEvents()
	}
	fmt.Println("no error reported")
}
