# UniformAnimator crashes when its ShaderEffect leaves the window

Minimal reproduction of a data race in Qt Quick. A running `UniformAnimator`
crashes the render thread when the GUI thread removes its target `ShaderEffect`
from the window.

## Environment

- Windows 11, Qt 6.11.2, MSVC 2022: D3D11 on an AMD GPU, and software rendering
  (`opengl32sw`, WARP)
- macOS 26, Apple M4 Max, Qt 6.11.0: Metal
- Threaded render loop in all cases
- The relevant code is the same in v6.11.0, v6.11.2, the 6.11 branch and dev
- Not tried on Linux

## Build and run

```bash
cmake -S . -B build -DCMAKE_PREFIX_PATH=<Qt>/msvc2022_64
cmake --build build --config Release
```

With `<Qt>/msvc2022_64/bin` on `PATH`:

```bash
python tools/run_stress.py build/Release/uniformanimator_race.exe --mode uniform --software
```

`--mode` picks how the tiles animate:

| Mode | Animation | Expected |
|---|---|---|
| `uniform` | `UniformAnimator` | crashes |
| `number` | `NumberAnimation` on the same property, GUI thread | control, does not crash |
| `xanimator` | `XAnimator` on the same item, render thread | control, does not crash |

`--software` selects the OpenGL backend with a CPU rasterizer, which hits the race
within seconds on Windows. Without it the crash still happens, usually later.

Do not use `--software` on macOS. AppKit aborts OpenGL on the render thread with
`-[NSOpenGLContext setView:] must be called from the main thread`, before any
animation starts. That is a different failure, unrelated to this race.

`run_stress.py` counts any non-zero exit as a crash, so check the stack when trying
a new platform.

## Results

Windows, runs of up to 40 s:

| Configuration | Crashed |
|---|---|
| `uniform`, software OpenGL | 6 of 6, within 2 to 7 s |
| `number`, software OpenGL | 0 of 3 |
| `xanimator`, software OpenGL | 0 of 3 |
| `uniform`, D3D11 on GPU, other load on the CPU | 2 of 3 |

The Windows GPU run shared the machine with another CPU-heavy process, so its rate
is not representative. On an idle machine that case can take much longer, or not
show up at all in a short run.

macOS, runs of up to 20 s:

| Configuration | Crashed |
|---|---|
| `uniform`, Metal | 6 of 6, `SIGSEGV` within 1.9 to 5.1 s |
| `number`, Metal | 0 of 3 |
| `xanimator`, Metal | 0 of 3 |

## Stack

Access violation reading `0x8` on the render thread:

```text
Qt6Quick!QQuickShaderEffect::updateUniformValue+0x227
Qt6Quick!QQuickUniformAnimatorJob::updateCurrentTime+0x126
Qt6Qml!QAbstractAnimationJob::setCurrentTime+0x172
Qt6Qml!QQmlAnimationTimer::updateAnimationsTime+0x7c
Qt6Core!QUnifiedTimer::updateAnimationTimers+0x14b
Qt6Core!QAnimationDriver::advanceAnimation+0x8f
```

GUI thread at the same moment:

```text
Qt6Quick!QQuickItemPrivate::derefWindow
Qt6Quick!QQuickItem::setParentItem
Qt6Quick!QQuickLoader::setActive
```

Symbols come from export tables, so frames are approximate. The offset matches the
source analysis below.

macOS, with exact symbols from `.dSYM`: `KERN_INVALID_ADDRESS at 0x8` on
`QSGRenderThread`:

```text
QQuickWindowPrivate::get(QQuickWindow*)
QQuickShaderEffectPrivate::updateUniformValue(...)+268
QQuickUniformAnimatorJob::updateCurrentTime(int)+220
QAbstractAnimationJob::setCurrentTime(int)+524
QQmlAnimationTimer::updateAnimationsTime(long long)+132
```

In the analyzed report the main thread was in `~QQuickShaderEffect`, which is a
later point of the same item teardown.

## Cause

`QQuickUniformAnimatorJob::updateCurrentTime()` runs on the render thread between
syncs, while the GUI thread is free to run. It calls into the live item:

```cpp
void QQuickUniformAnimatorJob::updateCurrentTime(int time)
{
    if (!m_effect || m_target != m_effect)
        return;

    m_value = m_from + (m_to - m_from) * progress(time);
    m_effect->updateUniformValue(m_uniform, m_value);
}
```

`QQuickShaderEffectPrivate::updateUniformValue()` then uses GUI thread state with no
synchronization:

```cpp
m_shaders[type].varData[idx].value = value;
// ...
sd.materialTypeCacheKey = q->window();
sd.viewCount = QQuickWindowPrivate::get(q->window())->multiViewCount();
```

When `derefWindow()` has just cleared the window, `q->window()` is null and
`QQuickWindowPrivate::get()` reads `d_ptr` at offset 8, which is the faulting
address. The `paintNode` null check in `QQuickShaderEffect::updateUniformValue()`
does not cover this, and neither would a null check on `window()`, because the
window can be cleared right after the check.

Transform and opacity animators are not affected: their jobs write only to state
owned by the render thread (`m_helper`, `m_opacityNode`), refreshed during sync.

## Related

[QTBUG-151922](https://qt-project.atlassian.net/browse/QTBUG-151922) is the report
for this repository. See also QTBUG-124152, QTBUG-119363 and QTBUG-89674.

## Possible fix

Keep the uniform job away from the item between syncs. Cache the node and the data
it needs during `postSync()`, when the GUI thread is blocked, and update the
material directly on the render thread. Removed nodes are deleted during the next
sync, so a pointer cached this way stays valid until it is refreshed.
