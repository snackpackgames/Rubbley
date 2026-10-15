# Android minimum-spec test phone

Researched 2026-10-14 for [#36 Benchmark N-body gravity on a minimum-spec phone](https://github.com/snackpackgames/Rubbley/issues/36).

**Question:** which cheap, low-spec, well-reviewed Android phone should Rubbley buy as its minimum-spec benchmark and touch-feel device? It has to be sold new in the US for roughly US$150 or less and meet Godot 4.7's floor: Android 9 + Vulkan 1.0 for the Mobile renderer, Android 7 + GLES 3.0 for Compatibility.

## Answer

| | Top pick: Samsung Galaxy A16 5G (US, SM-A166U) | Alt 1: Motorola Moto G Play (2026) | Alt 2: Samsung Galaxy A17 5G |
|---|---|---|---|
| Role | Typical low-end device (best-selling Android phone of 2025) | Lower CPU floor, 120 Hz | Same SoC as A16, newer, longer remaining support |
| Price (new, US) | ~$40-95 prepaid carrier-locked at Walmart; ~$174-200 unlocked | ~$40-50 prepaid carrier-locked at Walmart; $249.99 unlocked after the April 2026 price hike | $269.99 list at Samsung.com; ~$190 on sale |
| SoC | Exynos 1330 (5 nm; 2x A78 2.4 GHz + 6x A55 2.0 GHz) | MediaTek Dimensity 6300 (6 nm; 2x A76 2.4 GHz + 6x A55 2.0 GHz) | Exynos 1330 |
| GPU | Arm Mali-G68 MP2 (Valhall) | Arm Mali-G57 MC2 (Valhall) | Mali-G68 MP2 |
| RAM | 4 GB (base) | 4 GB | 4 GB (base); 6/8 GB variants |
| Display | 6.7" 1080x2340 Super AMOLED, 90 Hz | 6.7" 720p LCD, 120 Hz | 6.7" 1080x2340 Super AMOLED, 90 Hz |
| Android | Launched on Android 14; 6 OS upgrades / 6 yrs security (to ~Oct 2030) | Android 16; 2 OS upgrades / 3 yrs security | Launched on Android 15; 6 OS upgrades |
| Reviews | Well reviewed; strongest software policy in its class | Weak (Tom's Guide: "look elsewhere"; Notebookcheck aggregate 40-65%) | Good (GSMArena); modest upgrade over A16 |

**Buy the Galaxy A16 5G.** Get the US model (SM-A166U). At under $100 a prepaid unit fits the budget. An unlocked one is about $174, slightly over.

- **It represents real low-end hardware.** Counterpoint ranked it the best-selling Android phone of 2025 and fifth overall. The Exynos 1330 / Mali-G68 MP2 pairing is also in the US Galaxy A15 5G and the A17 5G, so a whole family of current Samsung entry phones shares this hardware.
- **It has the best update promise at this price**: six OS upgrades and six years of security patches.
- **It meets Godot's Mobile renderer floor.** It shipped on Android 14 and its GPU is a Mali Valhall part with Vulkan. (I did not verify the exact driver-reported Vulkan version; see "Not verified".)

**If the budget stretches, add a Moto G Play (2026) as a second floor.** A prepaid unit is about $40-50. Its Dimensity 6300 has Cortex-A76 big cores, a generation older than the Exynos 1330's A78s, so it is the lower CPU floor. The N-body benchmark will mostly load the CPU. Its Mali-G57 MC2 also covers the most common low-end GPU family. Its 120 Hz screen is the one to test godot#104179 on. Its reviews are poor, though, and its update window is short. That is why it is an alternate and not the top pick.

**The Galaxy A17 5G is the fallback** if no A16 is available. It has the same SoC, so the benchmark numbers would carry over. Its unlocked price is now well over budget.

## Prices are up in 2026

The "under $150 unlocked" budget-phone tier mostly disappeared this year. AI data-center demand caused a memory shortage that pushed list prices up.

- **Motorola** raised US prices in April 2026: Moto G Play $179.99 to $249.99, Moto G $199.99 to $299.99, Moto G Power $299.99 to $399.99 ([Android Authority](https://www.androidauthority.com/motorola-rolls-out-price-hikes-3655929), [9to5Google](https://9to5google.com/?p=710937)).
- **The Galaxy A17 5G** went from $199.99 to $249.99, then to $269.99 ([PhoneArena](https://www.phonearena.com/news/samsung-galaxy-a17-5g-amazon-prime-day-deal-actually-affordable-again_id183879)). Samsung.com currently lists the 128 GB model at $269.99 ([Samsung US](https://www.samsung.com/us/smartphones/galaxy-a17-5g/buy/)).
- **Prepaid carrier-locked units are still very cheap at Walmart.** Straight Talk / Total Wireless Galaxy A16 5G: $39.88-$94.95 ([Slickdeals, Aug 2026](https://slickdeals.net/f/19854201-straight-talk-samsung-galaxy-a16-5g-128gb-prepaid-smartphone-black-39-88-free-shipping), [Walmart](https://www.walmart.com/ip/Total-Wireless-Samsung-Galaxy-A16-128GB-5G-BLACK-Prepaid-Smartphone-Locked-to-Total-Wireless/12027650488)). Straight Talk / AT&T / Cricket Moto G Play (2026): $39.88-$49.88 ([Walmart](https://www.walmart.com/c/kp/moto-play)).

A carrier lock should not matter for a test device. Rubbley needs Wi-Fi, developer options and USB debugging, not cellular service. See "Not verified" below.

## Godot compatibility notes

- **godot#104179: "FPS is locked to 60 on Android 15, even with a 120 Hz display"** ([issue](https://github.com/godotengine/godot/issues/104179)). Still open. A maintainer (clayjohn) says Android 15 defaults games to 60 FPS unless the game opts out. Godot's Swappy integration (4.4+) only covers Vulkan, and a real fix needs the Android Frame Rate API. PR #122904 is open. Workaround: set the device's refresh rate from Auto to the fixed maximum in system settings.
  - **This affects all three phones.** With six OS upgrades promised, the A16 should be on Android 15 or later by now. I did not confirm its current OS version. The A17 and G Play ship on Android 15 and 16.
  - **During the benchmark,** record frame times with the refresh rate pinned. Expect 60 FPS as the ceiling unless the cap is bypassed. On a 90 Hz A16 that ceiling matters less than on a 120 Hz device.
- **Mali-specific Godot bugs.** None of the issues I found names the Exynos 1330 or the Dimensity 6300. There are general Mali driver crashes:
  - [#112157](https://github.com/godotengine/godot/issues/112157) "ARM Mali crash in `_uniform_set_update_shared()`" (4.5.1, Mobile/Vulkan; from Play Console data for a shipped game): closed.
  - [#119626](https://github.com/godotengine/godot/issues/119626) "Mobile Renderer crash on Mali GPU: SIGSEGV in libGLES_mali.so" (4.5.1, both renderers, no repro project): open, needs testing.
  - Older MediaTek Dimensity rendering issues ([#85750](https://github.com/godotengine/godot/issues/85750) tilemap tearing on Vulkan Mobile; [#91170](https://github.com/godotengine/godot/issues/91170) 3D mesh trembling) are both closed.
  - Taken together, Mali is the GPU family most likely to expose Godot driver bugs. That supports using a Mali phone as the floor device.

## Not verified

- **Driver-reported Vulkan version** on these exact phones. Mali-G57 and Mali-G68 are Valhall GPUs with Vulkan drivers, which clears Godot's Vulkan 1.0 floor. Confirm the exact version on the device with a gpuinfo/AIDA64 report or Godot's own startup log.
- **Whether prepaid units can finish setup on Wi-Fi without activating service.** Carrier-locked phones normally allow developer options and ADB. Some prepaid setup flows push for activation, so check the listing or plan to activate once.
- **Live prices.** The Walmart and Amazon figures are dated snapshots from August-October 2026 and move often.
- **The Galaxy A07 5G** (Dimensity 6300, 120 Hz, 6 OS upgrades) would be a good alternate, but I found no confirmed US launch or price.

## Sources

- Samsung Galaxy A16 5G update promise: [Samsung Newsroom (MY)](https://news.samsung.com/my/samsung-galaxy-a16-5g-built-to-last-with-6x-os-upgrades), [Android Central](https://androidcentral.com/phones/samsung-galaxy-a16-5g-six-year-promise-launch)
- A16 5G US model uses Exynos 1330 / Mali-G68: [Micro Center listing](https://www.microcenter.com/quickView/688470/samsung-galaxy-a16-unlocked-5g-black-smartphone), [CDW-G listing](https://www.cdwg.com/product/samsung-galaxy-a16-5g-128-gb-blue-black-5g-smartphone/8226110)
- A16 5G sales ranking: [Counterpoint Q3 2025](https://counterpointresearch.com/en/insights/top-10-best-selling-smartphones-q3-2025), [Android Authority Q3 2025](https://www.androidauthority.com/best-selling-android-phone-global-q3-2025-3623080/), [Heise full-year 2025](https://heise.de/-11159261)
- A16 5G pricing: [PhoneArena](https://www.phonearena.com/news/Samsungs-cheapest-5G-phone-is-now-even-cheaper-on-Amazon_id168739), [9to5Toys](https://9to5toys.com/2025/11/14/samsung-ultra-affordable-galaxy-a16-smartphone/), Walmart/Slickdeals links above
- Exynos 1330: [Samsung Semiconductor](https://semiconductor.samsung.com/processor/mobile-processor/exynos-1330/)
- Dimensity 6300: [MediaTek](https://www.mediatek.com/products/smartphones/mediatek-dimensity-6300)
- Galaxy A17 5G: [GSMArena review](https://m.gsmarena.com/samsung_galaxy_a17_5g-review-2869.php), [GSMArena specs](https://m.gsmarena.com/samsung_galaxy_a17_5g-14041.php), [Samsung US](https://www.samsung.com/us/smartphones/galaxy-a17-5g/buy/)
- Moto G Play (2026): [9to5Google launch specs](https://9to5google.com/2025/11/04/motorola-moto-g-2026-update-specs-price/), [GSMArena review](https://fo.gsmarena.com/motorola_moto_g_2026_g_play_2026-review-2925p6.php), [Tom's Guide review](https://www.tomsguide.com/phones/motorola-phones/motorola-moto-g-play-2026-review), [Android Central review (update policy)](https://androidcentral.com/phones/motorola/moto-g-play-2026-review), [Android Authority alternatives](https://androidauthority.com/moto-g-play-2026-alternatives-3687396)
- Godot issues: [#104179](https://github.com/godotengine/godot/issues/104179), [#112157](https://github.com/godotengine/godot/issues/112157), [#119626](https://github.com/godotengine/godot/issues/119626), [#85750](https://github.com/godotengine/godot/issues/85750), [#91170](https://github.com/godotengine/godot/issues/91170)
