using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace Kagura.Editor
{
    /// <summary>
    /// コマンドラインからシーン作成とビルドを行う。
    ///   Unity -batchmode -quit -projectPath . -executeMethod Kagura.Editor.BuildTools.CreateMainScene
    ///   Unity -batchmode -quit -projectPath . -executeMethod Kagura.Editor.BuildTools.BuildWeb
    /// </summary>
    public static class BuildTools
    {
        public const string ScenePath = "Assets/Kagura/Scenes/Main.unity";

        [MenuItem("Kagura/Create Main Scene")]
        public static void CreateMainScene()
        {
            Directory.CreateDirectory("Assets/Kagura/Scenes");
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            var camGo = new GameObject("Main Camera", typeof(Camera), typeof(AudioListener));
            camGo.tag = "MainCamera";
            var cam = camGo.GetComponent<Camera>();
            cam.orthographic = true;
            cam.orthographicSize = 4.8f;
            cam.transform.position = new Vector3(0, 0, -10);
            cam.clearFlags = CameraClearFlags.SolidColor;
            cam.backgroundColor = new Color(0.035f, 0.024f, 0.10f);
            // URP 2D レンダラの追加データ
            var add = camGo.AddComponent<UnityEngine.Rendering.Universal.UniversalAdditionalCameraData>();
            add.renderPostProcessing = true;

            var root = new GameObject("Game");
            root.AddComponent<Kagura.Game.Bootstrap>();

            var es = new GameObject("EventSystem", typeof(UnityEngine.EventSystems.EventSystem), typeof(UnityEngine.InputSystem.UI.InputSystemUIInputModule));
            es.SetActive(true);

            EnsureAssets();
            EditorSceneManager.SaveScene(scene, ScenePath);
            EditorBuildSettings.scenes = new[] { new EditorBuildSettingsScene(ScenePath, true) };
            AssetDatabase.SaveAssets();
            Debug.Log("[Kagura] scene created: " + ScenePath);
        }

        /// <summary>コードから Shader.Find で使うシェーダを、Resources のマテリアル経由でビルドに含める。</summary>
        public static void EnsureAssets()
        {
            Directory.CreateDirectory("Assets/Kagura/Resources/Materials");
            const string path = "Assets/Kagura/Resources/Materials/Vec.mat";
            if (AssetDatabase.LoadAssetAtPath<Material>(path) == null)
            {
                var sh = Shader.Find("Kagura/Vec");
                if (sh == null) { Debug.LogError("[Kagura] shader Kagura/Vec not found"); return; }
                AssetDatabase.CreateAsset(new Material(sh), path);
                AssetDatabase.SaveAssets();
                Debug.Log("[Kagura] created " + path);
            }
            // TextMeshPro の必須リソース（TMP Settings・SDF シェーダー）が無いと実行時に例外になる
            if (AssetDatabase.LoadAssetAtPath<UnityEngine.Object>("Assets/TextMesh Pro/Resources/TMP Settings.asset") == null)
            {
                string pkg = Path.GetFullPath("Packages/com.unity.ugui/Package Resources/TMP Essential Resources.unitypackage");
                if (!File.Exists(pkg)) pkg = Path.GetFullPath("Packages/com.unity.textmeshpro/Package Resources/TMP Essential Resources.unitypackage");
                if (File.Exists(pkg)) { AssetDatabase.ImportPackage(pkg, false); AssetDatabase.Refresh(); Debug.Log("[Kagura] imported TMP Essential Resources"); }
                else Debug.LogError("[Kagura] TMP Essential Resources package not found");
            }
            // Always Included Shaders にも入れる（Shader.Find をビルドでも確実に）
            var shader = Shader.Find("Kagura/Vec");
            var gs = AssetDatabase.LoadAllAssetsAtPath("ProjectSettings/GraphicsSettings.asset");
            if (shader != null && gs != null && gs.Length > 0)
            {
                var so = new SerializedObject(gs[0]);
                var arr = so.FindProperty("m_AlwaysIncludedShaders");
                bool has = false;
                for (int i = 0; i < arr.arraySize; i++) if (arr.GetArrayElementAtIndex(i).objectReferenceValue == shader) has = true;
                if (!has) { arr.InsertArrayElementAtIndex(arr.arraySize); arr.GetArrayElementAtIndex(arr.arraySize - 1).objectReferenceValue = shader; so.ApplyModifiedProperties(); Debug.Log("[Kagura] shader added to Always Included"); }
            }
        }

        [MenuItem("Kagura/Build Web")]
        public static void BuildWeb()
        {
            EnsureAssets();
            ApplyCommonSettings();
            PlayerSettings.WebGL.compressionFormat = WebGLCompressionFormat.Gzip;
            PlayerSettings.WebGL.decompressionFallback = true;   // GitHub Pages は Content-Encoding を付けないので JS 側で展開
            PlayerSettings.WebGL.template = "PROJECT:Kagura";   // Assets/WebGLTemplates/Kagura（全画面・縦・タッチ向け）
            PlayerSettings.runInBackground = true;
            // ブラウザでは縦画面のキャンバス（スマホ縦の比率）
            PlayerSettings.defaultWebScreenWidth = 480;
            PlayerSettings.defaultWebScreenHeight = 854;
            string outDir = Path.GetFullPath(Path.Combine(Application.dataPath, "../Build/Web"));
            var opts = new BuildPlayerOptions
            {
                scenes = new[] { ScenePath },
                locationPathName = outDir,
                target = BuildTarget.WebGL,
                options = BuildOptions.None,
            };
            var report = BuildPipeline.BuildPlayer(opts);
            Debug.Log($"[Kagura] web build {report.summary.result}: {report.summary.totalSize / 1048576f:F1} MB, {report.summary.totalTime.TotalSeconds:F0}s -> {outDir}");
            if (report.summary.result != UnityEditor.Build.Reporting.BuildResult.Succeeded)
                EditorApplication.Exit(1);
        }

        private static void ApplyCommonSettings()
        {
            PlayerSettings.companyName = "hiroakit";
            PlayerSettings.productName = "KAGURA ASCENT";
            PlayerSettings.defaultInterfaceOrientation = UIOrientation.Portrait;
            PlayerSettings.allowedAutorotateToPortrait = true;
            PlayerSettings.allowedAutorotateToPortraitUpsideDown = false;
            PlayerSettings.allowedAutorotateToLandscapeLeft = false;
            PlayerSettings.allowedAutorotateToLandscapeRight = false;
        }
    }
}
