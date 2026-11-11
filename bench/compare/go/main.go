// The comparison benchmark, in Go with miqt (github.com/mappu/miqt), a binding generated from
// Qt's headers through cgo. Same operations and counts as every other implementation (see
// ../README.md).
//
//	bench            the operations, one "RESULT <name> <value> <unit>" line each
//	bench --startup  start Qt, show a label, paint it once, exit (the runner times it)
package main

import (
	"fmt"
	"os"
	"time"

	qt "github.com/mappu/miqt/qt6"
)

const (
	n         = 200000
	nSignal   = 100000
	nObjects  = 50000
	rows      = 1000000
	lines     = 100000
	buttons   = 2000
	displayRl = 0 // Qt::DisplayRole
)

func result(name string, v float64, unit string) { fmt.Printf("RESULT %s %.3f %s\n", name, v, unit) }
func nsPer(t time.Time, k int) float64            { return float64(time.Since(t).Nanoseconds()) / float64(k) }
func msSince(t time.Time) float64                 { return float64(time.Since(t).Nanoseconds()) / 1e6 }

func main() {
	qt.NewQApplication(os.Args[:1])
	if len(os.Args) > 1 && os.Args[1] == "--startup" {
		hello := qt.NewQLabel3("hello")
		hello.Show()
		hello.Grab().Delete()
		return
	}
	label := qt.NewQLabel2()
	slider := qt.NewQSlider2()
	slider.SetMaximum(1 << 30)
	button := qt.NewQPushButton3("b")
	total, sum := 0, 0

	for i := 0; i < n/10; i++ {
		label.SetText("hello")
	}
	t := time.Now()
	for i := 0; i < n; i++ {
		label.SetText("hello")
	}
	result("set_text", nsPer(t, n), "ns")

	t = time.Now()
	for i := 0; i < n; i++ {
		total += len(label.Text())
	}
	result("get_text", nsPer(t, n), "ns")

	t = time.Now()
	for i := 0; i < n; i++ {
		slider.SetValue(i)
	}
	result("set_value", nsPer(t, n), "ns")

	t = time.Now()
	for i := 0; i < n; i++ {
		sum += slider.Value()
	}
	result("get_value", nsPer(t, n), "ns")

	t = time.Now()
	for i := 0; i < n; i++ {
		v := qt.NewQVariant11("hello")
		label.SetProperty("text", v)
		v.Delete()
	}
	result("set_property", nsPer(t, n), "ns")

	clicks := 0
	button.OnClicked(func() { clicks++ })
	t = time.Now()
	for i := 0; i < nSignal; i++ {
		button.Click()
	}
	result("signal", nsPer(t, nSignal), "ns")

	t = time.Now()
	for i := 0; i < n; i++ {
		c := qt.NewQColor3(255, 0, 0)
		sum += c.Red()
		c.Delete()
	}
	result("value_type", nsPer(t, n), "ns")

	t = time.Now()
	for i := 0; i < nObjects; i++ {
		qt.NewQObject().Delete()
	}
	result("object_churn", nsPer(t, nObjects), "ns")

	model := qt.NewQAbstractTableModel()
	model.OnRowCount(func(parent *qt.QModelIndex) int {
		if parent.IsValid() {
			return 0
		}
		return rows
	})
	model.OnColumnCount(func(parent *qt.QModelIndex) int {
		if parent.IsValid() {
			return 0
		}
		return 1
	})
	model.OnData(func(index *qt.QModelIndex, role int) *qt.QVariant {
		if role == displayRl {
			return qt.NewQVariant11(fmt.Sprintf("item %d", index.Row()))
		}
		return qt.NewQVariant()
	})
	proxy := qt.NewQSortFilterProxyModel()
	proxy.SetSourceModel(model.QAbstractItemModel)
	root := qt.NewQModelIndex()
	t = time.Now()
	proxy.SetFilterFixedString("4242")
	matches := proxy.RowCount(root)
	result("model_filter", msSince(t), "ms")
	result("model_matches", float64(matches), "rows")

	img := qt.NewQImage3(1024, 1024, qt.QImage__Format_ARGB32)
	img.Fill(0xffffffff)
	t = time.Now()
	p := qt.NewQPainter2(img.QPaintDevice)
	for i := 0; i < lines; i++ {
		x, y := (i*7)%1000, (i*13)%1000
		p.DrawLine2(x, y, x+8, y+5)
	}
	p.End()
	result("paint_lines", msSince(t), "ms")

	t = time.Now()
	win := qt.NewQWidget2()
	grid := qt.NewQGridLayout(win)
	for i := 0; i < buttons; i++ {
		grid.AddWidget2(qt.NewQPushButton3(fmt.Sprintf("b %d", i)).QWidget, i/40, i%40)
	}
	win.Show()
	win.Grab().Delete()
	win.Delete()
	qt.QCoreApplication_ProcessEvents()
	result("widgets", msSince(t), "ms")

	if clicks != nSignal || total == 0 || sum == 0 {
		os.Exit(1)
	}
}
