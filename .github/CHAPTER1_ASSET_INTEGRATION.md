# Chapter 1 asset integration

The runtime indexes `assets/chapter-1/sprites` at startup and prefers matching extracted sprites for the active game assets.

Currently mapped:

- Kris movement directions
- Susie
- Ralsei
- Rudinn / battle enemy
- Chapter 1 centered logo
- Chapter 1 battle background
- Chapter 1 menu image (available through the asset registry)

The existing placeholder assets remain as a fallback when an expected extracted sprite cannot be found or decoded.

Use `Assets:getSource(name)` to inspect which file was selected for an asset key at runtime.
