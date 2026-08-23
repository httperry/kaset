<img src="docs/screenshots/app-icon.png" width="84" height="84" alt="Kaset App Icon">

# Kaset — Homescreen Redesign

A complete visual redesign of the Kaset home experience on macOS.

---

## Video Demonstration

<p align="left">
  <img src="docs/screenshots/kaset-demo.gif" alt="Kaset Home Redesign Demonstration" width="850">
</p>

> Full-resolution walkthrough video: [`docs/screenshots/kaset-homescreen-demo.mp4`](docs/screenshots/kaset-homescreen-demo.mp4)

---

## Design Evolution: Before & After

<table>
  <tr>
    <th width="50%">Previous Interface</th>
    <th width="50%">Redesigned Home Interface</th>
  </tr>
  <tr>
    <td><img src="docs/screenshots/homescreen-legacy.png" alt="Previous Interface"></td>
    <td><img src="docs/screenshots/homescreen-dark.png" alt="Redesigned Interface"></td>
  </tr>
  <tr>
    <td valign="top">Standard flat list layout with basic grid carousels.</td>
    <td valign="top">Redesigned with a hero spotlight carousel, quick-resume Jump Back In shelf, animated audio visualizer, and macOS Liquid Glass styling.</td>
  </tr>
</table>

---

## Appearance Modes

<table>
  <tr>
    <th width="50%">Dark Mode</th>
    <th width="50%">Light Mode</th>
  </tr>
  <tr>
    <td><img src="docs/screenshots/homescreen-dark.png" alt="Dark Mode"></td>
    <td><img src="docs/screenshots/homescreen-light.png" alt="Light Mode"></td>
  </tr>
</table>

---

## Key Features

### Spotlight Hero Stage
- **Dynamic Artist Backdrops**: Features high-resolution artist artwork with smooth edge fading that naturally blends into the app background.
- **Featured Carousel**: Quick access to your top rotations and mixes with one-click playback and seamless navigation to album or playlist details.

### Jump Back In Shelf
- **Recent Highlight Card**: Prominently showcases your most relevant recent session with full-bleed artwork.
- **Smart Click Actions**: Click the album art to start playing immediately (or restart from 0:00 if already active), or click the title to view the full album or playlist.
- **Quick-Pick Columns**: Clean 3-row track list with translucent hover highlights for quick listening.

<table>
  <tr>
    <th width="50%">Jump Back In (Dark Mode)</th>
    <th width="50%">Jump Back In (Light Mode)</th>
  </tr>
  <tr>
    <td><img src="docs/screenshots/jump-back-in-dark.png" alt="Jump Back In Dark"></td>
    <td><img src="docs/screenshots/jump-back-in-light.png" alt="Jump Back In Light"></td>
  </tr>
</table>

### Now Playing Platter & Audio Visualizer
- **Glass Platter Indicator**: The active song card gently elevates with a translucent glass border to clearly show what's currently playing.
- **Live Visualizer Badge**: An animated 3-bar audio visualizer pill in the top-left corner indicates active playback in real time.

<table>
  <tr>
    <th width="50%">Playing Card Platter (Dark Mode)</th>
    <th width="50%">Playing Card Platter (Light Mode)</th>
  </tr>
  <tr>
    <td><img src="docs/screenshots/playing-card-dark.png" alt="Playing Card Dark"></td>
    <td><img src="docs/screenshots/playing-card-light.png" alt="Playing Card Light"></td>
  </tr>
</table>

### Smart On-Device Recommendations
Kaset tailors your home feed and shelf recommendations using an on-device affinity engine. Everything is calculated **100% locally and privately on your Mac**—your listening habits and history never leave your device:

$$
S(x, t) = \max\left(0, (1 - D_x) \cdot \left[ 25 \sum_{k=1}^{n} w_k (\Delta t_k)^{-0.5} + 25 \left(25 \, I_{\text{playlist}} + 15 \, I_{\text{liked}}\right) + 0.4 \, A_{\text{artist}} + E_{\text{album}} - 10 \, N_{\text{skip}} \right] - 1000 \, D_x \right)
$$

- **Recency & Attention** ($B_i = \sum w_k (\Delta t_k)^{-0.5}$): Tracks you listen to completely receive higher weights than quick skips, while recent plays naturally decay over time ($\Delta t_k$ hours) to keep recommendations fresh.
- **Explicit Favorites** ($I_{\text{playlist}}, I_{\text{liked}}$): Adding a song to a playlist (+25) or liking it (+15) gives it an immediate priority boost across shelves.
- **Artist Affinity** ($A_{\text{artist}}$): Tracks from artists you frequently listen to receive a scaled boost across recommendations.
- **Smart Rotation**: Prevents your top tracks from permanently monopolizing the spotlight, rotating candidates across listening sessions.
- **Dislike Suppression** ($D_x$): Disliked songs or artists receive a strong penalty ($-1000$) to immediately remove them from all recommendations.

---

## Building from Source

```bash
# Clone the feature branch
git clone -b redesign/homescreen https://github.com/httperry/Kaset.git
cd Kaset

# Build the project
swift build

# Package and run the app bundle
./Scripts/compile_and_run.sh --debug
```
