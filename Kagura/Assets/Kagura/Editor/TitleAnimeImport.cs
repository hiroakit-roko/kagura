using UnityEditor;
using UnityEngine;

namespace Kagura.Editor
{
    /// <summary>
    /// 題目のアニメ（Art/title_anime のアトラス）を、ビルドが太らないよう Crunch 圧縮・ミップ無しで取り込む。
    /// 2048px のアトラス 13 枚は DXT1 のままだと 26MB になるが、Crunch なら数 MB に収まる。
    /// </summary>
    public class TitleAnimeImport : AssetPostprocessor
    {
        private void OnPreprocessTexture()
        {
            if (!assetPath.Contains("/Art/title_anime/")) return;
            var ti = (TextureImporter)assetImporter;
            ti.textureType = TextureImporterType.Default;
            ti.mipmapEnabled = false;
            ti.isReadable = false;
            ti.sRGBTexture = true;
            ti.alphaSource = TextureImporterAlphaSource.None;
            ti.npotScale = TextureImporterNPOTScale.None;
            ti.wrapMode = TextureWrapMode.Clamp;
            ti.filterMode = FilterMode.Bilinear;
            ti.maxTextureSize = 2048;
            ti.textureCompression = TextureImporterCompression.Compressed;
            ti.crunchedCompression = true;
            ti.compressionQuality = 70;
        }
    }
}
