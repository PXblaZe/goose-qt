# Results

Intel(R) Xeon(R) Processor @ 2.10GHz, 2 cores, Linux-6.18.44-fc-v378-x86_64-with-glibc2.39; 2026-11-12. Median of 5 runs each (startup: 15 runs).

## Calls (ns per call)

| | C++ (direct) | C++ (direct), wheel Qt | C (qtc) | Goose (goose-qt), native | Goose (goose-qt), JIT | Rust (cxx-qt) | Python (PyQt6) | Python (PySide6) | Go (miqt) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| label.setText("hello") | 5.3 | 4.4 | 58 | 58 | 64 | 34 | 199 | 230 | 212 |
| label.text() | 1.9 | 2.3 | 66 | 66 | 78 | 16 | 151 | 242 | 176 |
| slider.setValue(i) | 28 | 36 | 56 | 55 | 56 | 30 | 158 | 255 | 83 |
| slider.value() | 0.7 | 1.0 | 21 | 20 | 23 | 3.4 | 108 | 196 | 57 |
| setProperty("text", ...) | 53 | 67 | 130 | 130 | 151 | 72 | 472 | 497 | 517 |
| button.click() reaching a handler | 93 | 101 | 213 | 212 | 238 | 98 | 726 | 372 | 221 |
| QColor(255, 0, 0).red() | 1.6 | 2.1 | 18 | 18 | 29 | 9.9 | 947 | 597 | 176 |
| new QObject, then delete it | 40 | 49 | 240 | 245 | 256 | 42 | 238 | 2203 | 151 |

## Whole tasks (ms)

| | C++ (direct) | C++ (direct), wheel Qt | C (qtc) | Goose (goose-qt), native | Goose (goose-qt), JIT | Rust (cxx-qt) | Python (PyQt6) | Python (PySide6) | Go (miqt) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| filter 1,000,000 rows of a model written in the language | 229 | 263 | 609 | 564 | 686 | 250 | 2201 | 2656 | 1213 |
| paint 100,000 short lines into a 1024x1024 QImage | 26.1 | 17.7 | 36.9 | 36.2 | 36.4 | 28.6 | 64.2 | 52.7 | 33.1 |
| 2,000 buttons in a grid: create, show, paint, destroy | 57.4 | 70.1 | 51.4 | 51.4 | 56.6 | 57.3 | 76.0 | 131 | 60.8 |
| startup to exit | 20.2 | 24.3 | 24.8 | 26.0 | 645 | 21.1 | 75.7 | 148 | 21.9 |

## Memory (MiB)

| | C++ (direct) | C++ (direct), wheel Qt | C (qtc) | Goose (goose-qt), native | Goose (goose-qt), JIT | Rust (cxx-qt) | Python (PyQt6) | Python (PySide6) | Go (miqt) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| peak RSS of the startup program | 29.5 | 27.3 | 38.8 | 39.0 | 241 | 30.6 | 48.6 | 56.5 | 43.5 |

## Spread (fastest and slowest run)

| | C++ (direct) | C++ (direct), wheel Qt | C (qtc) | Goose (goose-qt), native | Goose (goose-qt), JIT | Rust (cxx-qt) | Python (PyQt6) | Python (PySide6) | Go (miqt) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| label.setText("hello") | 5.0–5.8 | 4.0–8.7 | 55–59 | 55–67 | 50–67 | 29–48 | 162–269 | 220–365 | 196–244 |
| label.text() | 1.9–2.1 | 2.2–4.8 | 65–74 | 59–72 | 61–88 | 12–17 | 118–181 | 199–301 | 163–181 |
| slider.setValue(i) | 23–29 | 32–47 | 53–58 | 49–58 | 46–60 | 25–43 | 157–160 | 201–274 | 78–83 |
| slider.value() | 0.5–0.8 | 0.6–1.5 | 20–21 | 18–22 | 18–23 | 2.8–3.4 | 104–185 | 171–200 | 54–60 |
| setProperty("text", ...) | 42–55 | 57–90 | 128–136 | 121–135 | 112–186 | 60–98 | 392–486 | 495–507 | 486–539 |
| button.click() reaching a handler | 77–99 | 92–130 | 208–220 | 195–222 | 191–341 | 82–122 | 551–781 | 352–389 | 209–230 |
| QColor(255, 0, 0).red() | 1.4–1.8 | 1.6–3.0 | 18–18 | 18–25 | 22–39 | 8.3–13 | 733–973 | 540–892 | 165–179 |
| new QObject, then delete it | 34–44 | 42–69 | 229–245 | 236–248 | 205–322 | 36–70 | 183–272 | 2066–3371 | 142–152 |
| filter 1,000,000 rows of a model written in the language | 219–239 | 256–270 | 597–707 | 525–662 | 679–742 | 204–300 | 2047–2228 | 2580–2860 | 1064–1334 |
| paint 100,000 short lines into a 1024x1024 QImage | 23–29 | 17–27 | 35–44 | 30–39 | 31–51 | 25–29 | 51–71 | 50–133 | 27–34 |
| 2,000 buttons in a grid: create, show, paint, destroy | 53–87 | 63–98 | 47–53 | 42–66 | 47–81 | 51–59 | 63–109 | 120–165 | 52–64 |
