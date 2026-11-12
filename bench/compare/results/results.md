# Results

Intel(R) Xeon(R) Processor @ 2.10GHz, 2 cores, Linux-6.18.44-fc-v378-x86_64-with-glibc2.39; 2026-11-12. Median of 5 runs each (startup: 15 runs).

## Calls (ns per call)

| | C++ (direct) | C++ (direct), wheel Qt | C (qtc) | Goose (goose-qt), native | Goose (goose-qt), JIT | Rust (cxx-qt) | Python (PyQt6) | Python (PySide6) | Go (miqt) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| label.setText("hello") | 5.5 | 3.7 | 58 | 58 | 68 | 34 | 143 | 265 | 198 |
| label.text() | 2.1 | 2.3 | 66 | 67 | 91 | 15 | 130 | 266 | 157 |
| slider.setValue(i) | 29 | 31 | 55 | 54 | 56 | 31 | 139 | 255 | 74 |
| slider.value() | 0.7 | 0.7 | 21 | 20 | 26 | 3.5 | 96 | 194 | 51 |
| setProperty("text", ...) | 53 | 55 | 131 | 135 | 156 | 71 | 418 | 589 | 478 |
| button.click() reaching a handler | 96 | 96 | 215 | 213 | 337 | 99 | 607 | 426 | 209 |
| QColor(255, 0, 0).red() | 1.7 | 2.1 | 18 | 18 | 40 | 9.9 | 902 | 586 | 167 |
| new QObject, then delete it | 41 | 42 | 178 | 178 | 232 | 43 | 223 | 2003 | 139 |

## Whole tasks (ms)

| | C++ (direct) | C++ (direct), wheel Qt | C (qtc) | Goose (goose-qt), native | Goose (goose-qt), JIT | Rust (cxx-qt) | Python (PyQt6) | Python (PySide6) | Go (miqt) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| filter 1,000,000 rows of a model written in the language | 260 | 238 | 588 | 553 | 798 | 254 | 2113 | 2455 | 1270 |
| paint 100,000 short lines into a 1024x1024 QImage | 26.8 | 23.0 | 31.2 | 32.8 | 37.3 | 25.0 | 66.5 | 44.8 | 34.7 |
| 2,000 buttons in a grid: create, show, paint, destroy | 62.7 | 81.0 | 42.6 | 44.9 | 54.5 | 55.4 | 78.6 | 113 | 61.3 |
| startup to exit | 22.1 | 28.4 | 28.8 | 28.5 | 646 | 21.6 | 75.4 | 152 | 21.3 |

## Memory (MiB)

| | C++ (direct) | C++ (direct), wheel Qt | C (qtc) | Goose (goose-qt), native | Goose (goose-qt), JIT | Rust (cxx-qt) | Python (PyQt6) | Python (PySide6) | Go (miqt) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| peak RSS of the startup program | 29.3 | 27.3 | 38.7 | 39.0 | 241 | 30.4 | 48.4 | 56.3 | 43.4 |

## Spread (fastest and slowest run)

| | C++ (direct) | C++ (direct), wheel Qt | C (qtc) | Goose (goose-qt), native | Goose (goose-qt), JIT | Rust (cxx-qt) | Python (PyQt6) | Python (PySide6) | Go (miqt) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| label.setText("hello") | 4.4–5.7 | 3.1–7.3 | 45–75 | 46–91 | 56–122 | 28–47 | 131–232 | 202–310 | 172–219 |
| label.text() | 1.5–2.4 | 1.9–3.3 | 52–73 | 52–96 | 70–163 | 13–19 | 113–162 | 253–352 | 142–186 |
| slider.setValue(i) | 23–36 | 26–39 | 41–61 | 41–75 | 51–83 | 27–44 | 121–247 | 225–304 | 65–90 |
| slider.value() | 0.5–0.7 | 0.6–0.9 | 16–26 | 16–34 | 21–55 | 3.0–4.5 | 82–174 | 184–225 | 45–64 |
| setProperty("text", ...) | 43–57 | 48–60 | 102–160 | 106–160 | 130–248 | 64–99 | 365–705 | 456–690 | 418–559 |
| button.click() reaching a handler | 76–124 | 79–111 | 179–269 | 169–294 | 243–505 | 88–116 | 575–630 | 373–484 | 174–266 |
| QColor(255, 0, 0).red() | 1.3–4.9 | 1.4–2.9 | 15–22 | 14–23 | 23–41 | 8.8–11 | 806–1040 | 480–707 | 138–203 |
| new QObject, then delete it | 34–45 | 33–62 | 156–231 | 140–287 | 159–366 | 38–64 | 195–244 | 1696–2434 | 118–154 |
| filter 1,000,000 rows of a model written in the language | 188–364 | 210–320 | 506–616 | 442–629 | 595–865 | 216–332 | 1984–2177 | 2298–2552 | 1119–1332 |
| paint 100,000 short lines into a 1024x1024 QImage | 26–43 | 16–35 | 28–36 | 29–37 | 32–49 | 23–29 | 64–80 | 41–131 | 28–38 |
| 2,000 buttons in a grid: create, show, paint, destroy | 56–100 | 61–104 | 42–53 | 41–51 | 48–67 | 50–58 | 67–128 | 104–144 | 56–65 |
