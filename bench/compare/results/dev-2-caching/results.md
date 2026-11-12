# Results

Intel(R) Xeon(R) Processor @ 2.10GHz, 2 cores, Linux-6.18.44-fc-v378-x86_64-with-glibc2.39; 2026-11-11. Median of 5 runs each (startup: 15 runs).

## Calls (ns per call)

| | C++ (direct) | C++ (direct), wheel Qt | C (qtc) | Goose (goose-qt), native | Goose (goose-qt), JIT | Python (PyQt6) | Python (PySide6) | Go (miqt) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| label.setText("hello") | 5.2 | 5.5 | 164 | 157 | 162 | 169 | 270 | 241 |
| label.text() | 3.4 | 3.5 | 135 | 151 | 168 | 154 | 274 | 185 |
| slider.setValue(i) | 30 | 34 | 159 | 158 | 161 | 166 | 285 | 93 |
| slider.value() | 2.1 | 2.2 | 104 | 100 | 108 | 118 | 227 | 67 |
| setProperty("text", ...) | 69 | 72 | 306 | 297 | 327 | 542 | 597 | 617 |
| button.click() reaching a handler | 103 | 113 | 383 | 374 | 429 | 836 | 418 | 306 |
| QColor(255, 0, 0).red() | 2.7 | 2.7 | 433 | 443 | 482 | 986 | 613 | 190 |
| new QObject, then delete it | 44 | 50 | 1667 | 1577 | 1930 | 260 | 2396 | 172 |

## Whole tasks (ms)

| | C++ (direct) | C++ (direct), wheel Qt | C (qtc) | Goose (goose-qt), native | Goose (goose-qt), JIT | Python (PyQt6) | Python (PySide6) | Go (miqt) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| filter 1,000,000 rows of a model written in the language | 288 | 309 | 720 | 683 | 821 | 2518 | 2975 | 1552 |
| paint 100,000 short lines into a 1024x1024 QImage | 29.7 | 17.6 | 35.0 | 37.9 | 37.4 | 69.1 | 51.8 | 35.3 |
| 2,000 buttons in a grid: create, show, paint, destroy | 59.3 | 70.9 | 56.0 | 57.0 | 56.9 | 80.4 | 133 | 61.4 |
| startup to exit | 17.6 | 22.6 | 43.8 | 50.9 | 541 | 70.0 | 141 | 21.7 |

## Memory (MiB)

| | C++ (direct) | C++ (direct), wheel Qt | C (qtc) | Goose (goose-qt), native | Goose (goose-qt), JIT | Python (PyQt6) | Python (PySide6) | Go (miqt) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| peak RSS of the startup program | 29.3 | 27.3 | 65.1 | 65.4 | 240 | 48.4 | 56.3 | 35.5 |

## Spread (fastest and slowest run)

| | C++ (direct) | C++ (direct), wheel Qt | C (qtc) | Goose (goose-qt), native | Goose (goose-qt), JIT | Python (PyQt6) | Python (PySide6) | Go (miqt) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| label.setText("hello") | 4.9–5.8 | 5.3–6.0 | 144–201 | 148–247 | 159–290 | 163–289 | 261–292 | 219–279 |
| label.text() | 2.7–3.5 | 3.3–3.6 | 131–249 | 143–158 | 165–189 | 144–170 | 270–331 | 179–338 |
| slider.setValue(i) | 29–41 | 33–38 | 150–305 | 152–191 | 158–223 | 158–249 | 278–307 | 84–143 |
| slider.value() | 2.1–2.3 | 2.1–2.4 | 97–156 | 93–119 | 100–132 | 109–155 | 211–249 | 60–87 |
| setProperty("text", ...) | 63–78 | 67–84 | 299–329 | 295–448 | 313–445 | 488–735 | 555–1140 | 549–862 |
| button.click() reaching a handler | 102–115 | 104–130 | 359–390 | 360–384 | 389–461 | 764–877 | 391–488 | 267–347 |
| QColor(255, 0, 0).red() | 2.6–2.9 | 2.4–7.5 | 425–488 | 409–447 | 444–520 | 972–1132 | 608–670 | 184–230 |
| new QObject, then delete it | 42–51 | 46–61 | 1591–2805 | 1559–1838 | 1795–2155 | 240–264 | 2257–3420 | 157–173 |
| filter 1,000,000 rows of a model written in the language | 255–313 | 279–359 | 713–762 | 666–712 | 773–921 | 2367–2770 | 2799–3359 | 1505–1746 |
| paint 100,000 short lines into a 1024x1024 QImage | 26–33 | 17–70 | 34–39 | 35–39 | 36–45 | 68–73 | 50–55 | 33–48 |
| 2,000 buttons in a grid: create, show, paint, destroy | 56–62 | 64–80 | 54–63 | 54–63 | 56–61 | 78–139 | 123–143 | 59–63 |
