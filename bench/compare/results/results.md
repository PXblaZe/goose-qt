# Results

Intel(R) Xeon(R) Processor @ 2.10GHz, 2 cores, Linux-6.18.44-fc-v378-x86_64-with-glibc2.39; 2026-11-12. Median of 5 runs each (startup: 15 runs).

## Calls (ns per call)

| | C++ (direct) | C++ (direct), wheel Qt | C (qtc) | Goose (goose-qt), native | Goose (goose-qt), JIT | Rust (cxx-qt) | Python (PyQt6) | Python (PySide6) | Go (miqt) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| label.setText("hello") | 4.5 | 3.7 | 55 | 51 | 65 | 33 | 143 | 206 | 232 |
| label.text() | 1.7 | 2.3 | 60 | 67 | 104 | 15 | 132 | 213 | 173 |
| slider.setValue(i) | 26 | 33 | 51 | 51 | 75 | 30 | 161 | 218 | 75 |
| slider.value() | 0.7 | 0.7 | 16 | 20 | 22 | 3.4 | 111 | 176 | 55 |
| setProperty("text", ...) | 49 | 59 | 134 | 139 | 185 | 71 | 496 | 452 | 492 |
| button.click() reaching a handler | 81 | 97 | 168 | 157 | 196 | 100 | 693 | 312 | 185 |
| button.click(), queued and polled (qtc, goose-qt) |  |  | 207 | 159 | 288 |  |  |  |  |
| QColor(255, 0, 0).red() | 1.7 | 1.8 | 18 | 15 | 31 | 10 | 966 | 464 | 162 |
| new QObject, then delete it | 40 | 43 | 156 | 135 | 211 | 42 | 220 | 1945 | 141 |

## Whole tasks (ms)

| | C++ (direct) | C++ (direct), wheel Qt | C (qtc) | Goose (goose-qt), native | Goose (goose-qt), JIT | Rust (cxx-qt) | Python (PyQt6) | Python (PySide6) | Go (miqt) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| filter 1,000,000 rows of a model written in the language | 232 | 220 | 622 | 510 | 711 | 250 | 2144 | 2476 | 1202 |
| paint 100,000 short lines into a 1024x1024 QImage | 27.6 | 17.4 | 36.6 | 32.0 | 38.8 | 28.5 | 54.4 | 49.9 | 34.1 |
| 2,000 buttons in a grid: create, show, paint, destroy | 65.1 | 67.2 | 43.5 | 45.1 | 54.1 | 54.3 | 70.1 | 121 | 64.9 |
| startup to exit | 17.1 | 21.2 | 21.9 | 23.6 | 430 | 20.5 | 70.4 | 145 | 19.4 |

## Memory (MiB)

| | C++ (direct) | C++ (direct), wheel Qt | C (qtc) | Goose (goose-qt), native | Goose (goose-qt), JIT | Rust (cxx-qt) | Python (PyQt6) | Python (PySide6) | Go (miqt) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| peak RSS of the startup program | 29.3 | 27.4 | 39.0 | 39.2 | 183 | 30.3 | 48.5 | 56.4 | 43.4 |

## Spread (fastest and slowest run)

| | C++ (direct) | C++ (direct), wheel Qt | C (qtc) | Goose (goose-qt), native | Goose (goose-qt), JIT | Rust (cxx-qt) | Python (PyQt6) | Python (PySide6) | Go (miqt) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| label.setText("hello") | 4.1–5.4 | 2.9–7.1 | 53–87 | 43–91 | 59–107 | 33–39 | 134–213 | 187–244 | 163–303 |
| label.text() | 1.5–1.9 | 1.8–3.6 | 53–64 | 48–87 | 76–121 | 15–21 | 120–173 | 192–246 | 138–291 |
| slider.setValue(i) | 23–28 | 25–38 | 47–71 | 38–67 | 51–84 | 29–31 | 122–185 | 189–251 | 66–134 |
| slider.value() | 0.5–1.0 | 0.5–1.2 | 16–25 | 12–27 | 20–34 | 3.2–3.4 | 84–150 | 158–201 | 45–88 |
| setProperty("text", ...) | 42–56 | 46–70 | 126–168 | 102–192 | 135–220 | 67–73 | 453–559 | 400–529 | 407–545 |
| button.click() reaching a handler | 74–96 | 75–103 | 152–225 | 128–207 | 166–254 | 95–112 | 597–704 | 302–410 | 176–231 |
| button.click(), queued and polled (qtc, goose-qt) |  |  | 169–301 | 151–176 | 240–360 |  |  |  |  |
| QColor(255, 0, 0).red() | 1.3–2.2 | 1.6–3.2 | 15–26 | 14–16 | 26–41 | 9.5–11 | 794–1097 | 436–596 | 139–229 |
| new QObject, then delete it | 32–51 | 33–49 | 135–232 | 132–138 | 162–339 | 40–44 | 186–275 | 1716–2408 | 119–206 |
| filter 1,000,000 rows of a model written in the language | 217–265 | 202–335 | 547–664 | 484–587 | 598–774 | 223–273 | 1979–2304 | 2340–2785 | 1142–1276 |
| paint 100,000 short lines into a 1024x1024 QImage | 26–44 | 14–20 | 29–48 | 30–46 | 30–59 | 23–48 | 50–84 | 42–102 | 26–36 |
| 2,000 buttons in a grid: create, show, paint, destroy | 54–86 | 53–82 | 40–68 | 42–61 | 42–75 | 45–81 | 64–88 | 101–141 | 59–81 |
