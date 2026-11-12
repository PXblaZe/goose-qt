# Results

Intel(R) Xeon(R) Processor @ 2.30GHz, 2 cores, Linux-6.18.44-fc-v378-x86_64-with-glibc2.39; 2026-11-12. Median of 5 runs each (startup: 15 runs).

## Calls (ns per call)

| | C++ (direct) | C++ (direct), wheel Qt | C (qtc) | Goose (goose-qt), native | Goose (goose-qt), JIT | Rust (cxx-qt) | Python (PyQt6) | Python (PySide6) | Go (miqt) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| label.setText("hello") | 4.4 | 3.2 | 49 | 51 | 56 | 29 | 160 | 195 | 175 |
| label.text() | 1.8 | 1.9 | 54 | 57 | 68 | 13 | 122 | 208 | 146 |
| slider.setValue(i) | 24 | 27 | 43 | 42 | 43 | 26 | 133 | 205 | 70 |
| slider.value() | 0.6 | 0.6 | 18 | 17 | 19 | 2.9 | 93 | 168 | 48 |
| setProperty("text", ...) | 45 | 50 | 106 | 109 | 118 | 60 | 397 | 415 | 434 |
| button.click() reaching a handler | 80 | 81 | 173 | 180 | 202 | 83 | 598 | 307 | 186 |
| QColor(255, 0, 0).red() | 1.4 | 1.7 | 139 | 140 | 152 | 8.3 | 802 | 483 | 148 |
| new QObject, then delete it | 35 | 36 | 205 | 208 | 230 | 36 | 196 | 1829 | 128 |

## Whole tasks (ms)

| | C++ (direct) | C++ (direct), wheel Qt | C (qtc) | Goose (goose-qt), native | Goose (goose-qt), JIT | Rust (cxx-qt) | Python (PyQt6) | Python (PySide6) | Go (miqt) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| filter 1,000,000 rows of a model written in the language | 203 | 231 | 512 | 508 | 569 | 212 | 1869 | 2207 | 1037 |
| paint 100,000 short lines into a 1024x1024 QImage | 22.2 | 14.5 | 30.7 | 30.7 | 31.1 | 23.7 | 54.3 | 41.6 | 27.9 |
| 2,000 buttons in a grid: create, show, paint, destroy | 48.1 | 56.6 | 45.0 | 45.0 | 45.1 | 49.4 | 64.6 | 108 | 53.4 |
| startup to exit | 17.2 | 21.0 | 20.8 | 22.0 | 549 | 18.5 | 66.1 | 133 | 18.5 |

## Memory (MiB)

| | C++ (direct) | C++ (direct), wheel Qt | C (qtc) | Goose (goose-qt), native | Goose (goose-qt), JIT | Rust (cxx-qt) | Python (PyQt6) | Python (PySide6) | Go (miqt) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| peak RSS of the startup program | 29.6 | 27.4 | 38.7 | 38.9 | 230 | 30.6 | 48.6 | 56.6 | 43.5 |

## Spread (fastest and slowest run)

| | C++ (direct) | C++ (direct), wheel Qt | C (qtc) | Goose (goose-qt), native | Goose (goose-qt), JIT | Rust (cxx-qt) | Python (PyQt6) | Python (PySide6) | Go (miqt) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| label.setText("hello") | 4.3–4.4 | 3.1–5.9 | 47–52 | 47–64 | 52–57 | 28–30 | 135–172 | 190–198 | 173–177 |
| label.text() | 1.8–2.0 | 1.9–2.9 | 53–55 | 56–58 | 66–74 | 13–14 | 121–160 | 203–217 | 146–151 |
| slider.setValue(i) | 23–24 | 27–34 | 42–43 | 41–43 | 42–45 | 25–26 | 130–153 | 203–206 | 69–70 |
| slider.value() | 0.6–0.9 | 0.6–0.6 | 17–19 | 17–18 | 19–21 | 2.8–3.1 | 90–96 | 164–182 | 47–48 |
| setProperty("text", ...) | 43–45 | 50–54 | 103–120 | 107–123 | 111–163 | 59–64 | 389–521 | 406–427 | 430–456 |
| button.click() reaching a handler | 77–87 | 80–94 | 169–185 | 175–244 | 195–322 | 81–84 | 588–711 | 303–321 | 186–242 |
| QColor(255, 0, 0).red() | 1.4–1.4 | 1.4–2.1 | 136–158 | 137–153 | 146–230 | 8.2–8.4 | 777–874 | 444–503 | 147–191 |
| new QObject, then delete it | 34–35 | 34–52 | 203–210 | 208–210 | 217–240 | 35–36 | 193–305 | 1817–1846 | 127–141 |
| filter 1,000,000 rows of a model written in the language | 191–261 | 214–245 | 504–521 | 477–561 | 556–637 | 205–248 | 1824–1958 | 2092–2222 | 991–1078 |
| paint 100,000 short lines into a 1024x1024 QImage | 22–23 | 14–20 | 30–31 | 29–37 | 30–33 | 23–24 | 54–56 | 41–43 | 27–35 |
| 2,000 buttons in a grid: create, show, paint, destroy | 47–49 | 54–75 | 42–46 | 44–50 | 44–46 | 49–50 | 63–72 | 107–111 | 51–55 |
