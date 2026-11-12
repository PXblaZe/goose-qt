// The misuse probes, one per run: misuse CASE (see run.py for the list)
package main

import (
	"fmt"
	"os"
	"strconv"

	qt "github.com/mappu/miqt/qt6"
)

func main() {
	c := os.Args[1]
	if c == "before_app" {
		l := qt.NewQLabel3("x")
		l.Show()
		fmt.Println("no error reported")
		return
	}
	qt.NewQApplication(os.Args[:1])
	switch c {
	case "deleted":
		w := qt.NewQWidget2()
		l := qt.NewQLabel5("x", w)
		w.Delete()
		l.SetText("y")
	case "deleted_self":
		l := qt.NewQLabel3("x")
		l.Delete()
		l.SetText("y")
	case "double_delete":
		l := qt.NewQLabel3("x")
		l.Delete()
		l.Delete()
	case "stale_index":
		m := qt.NewQStandardItemModel2(2, 1)
		i := m.Index(1, 0, qt.NewQModelIndex())
		m.Clear()
		m.SetData(i, qt.NewQVariant11("b"), 2)
	case "held_deleted":
		t := qt.NewQTableWidget3(2, 2)
		b := qt.NewQPushButton3("x")
		t.SetCellWidget(0, 0, b.QWidget)
		t.Show()
		qt.QCoreApplication_ProcessEvents()
		b.Delete()
		t.Resize(400, 300)
		qt.QCoreApplication_ProcessEvents()
	case "null":
		qt.NewQComboBox2().LineEdit().SetText("x")
	case "range":
		qt.NewQSpinBox2().SetValue(10000000000)
	case "wrong_thread":
		l := qt.NewQLabel3("x")
		l.Show()
		done := make(chan bool)
		go func() {
			for i := 0; i < 1000; i++ {
				l.SetText(strconv.Itoa(i))
			}
			done <- true
		}()
		for i := 0; i < 1000; i++ {
			qt.QCoreApplication_ProcessEvents()
		}
		<-done
	case "qtbug":
		cb := qt.NewQComboBox2()
		cb.AddItem("a")
		cb.SetView(cb.View())
		cb.ShowPopup()
		qt.QCoreApplication_ProcessEvents()
	}
	fmt.Println("no error reported")
}
