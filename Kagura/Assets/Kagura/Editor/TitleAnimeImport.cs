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
            bool boss = assetPath.Contains("/Art/boss/") && assetPath.Contains("_anim");
            if (!assetPath.Contains("/Art/title_anime/") && !boss) return;
            var ti = (TextureImporter)assetImporter;
            if (boss)
            {   // ボスの連番：横に長い 1 枚（透過）。縮められないよう上限を広げ、ミップ無し
                ti.textureType = TextureImporterType.Default; ti.mipmapEnabled = false; ti.isReadable = false; ti.sRGBTexture = true;
                ti.alphaSource = TextureImporterAlphaSource.FromInput; ti.alphaIsTransparency = true; ti.npotScale = TextureImporterNPOTScale.None;
                ti.wrapMode = TextureWrapMode.Clamp; ti.filterMode = FilterMode.Bilinear; ti.maxTextureSize = 8192;
                ti.textureCompression = TextureImporterCompression.Compressed; ti.crunchedCompression = false;
                return;
            }
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
