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
            add.renderPostProcessing = false;

            var root = new GameObject("Game");
            root.AddComponent<Kagura.Game.Bootstrap>();

            var es = new GameObject("EventSystem", typeof(UnityEngine.EventSystems.EventSystem), typeof(UnityEngine.InputSystem.UI.InputSystemUIInputModule));
            es.SetActive(true);

            EditorSceneManager.SaveScene(scene, ScenePath);
            EditorBuildSettings.scenes = new[] { new EditorBuildSettingsScene(ScenePath, true) };
            AssetDatabase.SaveAssets();
            Debug.Log("[Kagura] scene created: " + ScenePath);
        }

        [MenuItem("Kagura/Build Web")]
        public static void BuildWeb()
        {
            ApplyCommonSettings();
            PlayerSettings.WebGL.compressionFormat = WebGLCompressionFormat.Gzip;
            PlayerSettings.WebGL.decompressionFallback = true;   // GitHub Pages は Content-Encoding を付けないので JS 側で展開
            PlayerSettings.WebGL.template = "APPLICATION:Default";
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
