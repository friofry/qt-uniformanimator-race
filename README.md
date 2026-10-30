# UniformAnimator crashes when its ShaderEffect leaves the window

Minimal reproduction of a data race in Qt Quick. A running `UniformAnimator`
crashes the render thread when the GUI thread removes its target `ShaderEffect`
from the window.

## Environment

- Qt 6.11.2, MSVC 2022, Windows 11, threaded render loop
- Reproduces with hardware rendering (D3D11, AMD) and with software rendering
  (`opengl32sw`, WARP)
- The relevant code is the same in v6.11.0, v6.11.2, the 6.11 branch and dev
- Not tried on Linux or macOS

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
within seconds. Without it the crash still happens, usually later.

## Results

Each run lasted up to 40 s:

| Configuration | Crashed |
|---|---|
| `uniform`, software OpenGL | 6 of 6, within 2 to 7 s |
| `number`, software OpenGL | 0 of 3 |
| `xanimator`, software OpenGL | 0 of 3 |
| `uniform`, D3D11 on GPU, other load on the CPU | 2 of 3 |

The GPU run shared the machine with another CPU-heavy process, so its rate is not
representative. On an idle machine the GPU case can take much longer, or not show
up at all in a short run.

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

## Possible fix

Keep the uniform job away from the item between syncs. Cache the node and the data
it needs during `postSync()`, when the GUI thread is blocked, and update the
material directly on the render thread. Removed nodes are deleted during the next
sync, so a pointer cached this way stays valid until it is refreshed.
