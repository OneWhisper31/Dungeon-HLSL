Shader "Unlit/S_PBR"
{
    Properties
    {
        _MainTex ("Base Map", 2D) = "white" {}
        _BaseColor ("Base Color", Color) = (1,1,1,1)
        
        [Space(20)]
        [Toggle(_ALPHATEST_ON)] _AlphaTestToggle("Alpha Clip", Float) = 0
        _AlphaClip("Clip", Range(0,1)) = 0.5
        
        [Space(20)]
        _Metallic("Metallic", Range(0,1)) = 0
        _Smoothness("Smoothness", Range(0,1)) = 0.5
        _MetallicSpecGloss("Specular Or Metallic Map", 2D) = "black" {}
        
        [Space(20)]
        [Toggle(_NORMALMAP)] _UseNormalMap("Use Normal Map", Float) = 0
        _NormalMap("Normal Map", 2D) = "bump" {}
        _NormalScale("Normal Scale", Float) = 1
        
        [Space(20)]
        _OcclusionMap("Occlusion Map",2D) = "white"{}
        _OcclusionMultiplier("Occlusion Multiplier",Range(0,1))=1
        
        [Space(20)]
        _EmissionMap("Emission Map", 2D) = "black"{}
        [HDR] _EmissionColor("Emission Color",Color) = (0,0,0)
        
        [Space(20)]
        [Toggle(_SPECULARHIGHLIGHTS_OFF)] _SpecularHighLights("Specular HighLights", Float) = 0
        [Toggle(_ENVIRONMENTREFLECTIONS_OFF)] _EnvironmentReflections("Environment Reflections", Float) = 0
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Transparent"
            "Queue" = "Geometry"
        }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        CBUFFER_START(UnityPerMaterial)
            half4 _MainTex_ST;
            half4 _BaseColor;
            half4 _SpecularColor;
            half3 _EmissionColor;
            half _AlphaClip;
            half _Metalic;
            half _Smoothness;
            half _NormalScale;
            half _OcclusionMultiplier;
        CBUFFER_END
        ENDHLSL

        Pass
        {
            Name "ForwardLit"
            
            Tags
            {
                "LightMode" = "UniversalForward"
            }
            
            HLSLPROGRAM

            #pragma vertex PBRVertex
            #pragma fragment PBRFragment

            //Material Keywords
            #pragma shader_feature_local _NORMALMAP

            //Unity Keywords
            #pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature_local_fragment _SPECTULAR_SETUP
            #pragma shader_feature_local _RECEIVE_SHADOWS_OFF

            //URP Keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHTS_SHADOWS
            #pragma multi_compile _ _MIXED_LIGHTNING_SUBTRACTIVE
            #pragma multi_compile _ SHADOWS_MASK
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION //SSAO

            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile_fog

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;
            
                #if _NORMALMAP
                float4 tangentOS    : TANGENT;
                #endif
            
                float4 normalOS     : NORMAL;
                half2  uv           : TEXCOORD0;
                half2  lighmapUV    : TEXCOORD1;
            };

            struct Varyings
            {
                float4 positionCS    : SV_POSITION;
                half2  uv            : TEXCOORD0;
                DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH,1);
                float3 positionWS    : TEXCOORD2;

                #if _NORMALMAP
                    half3  normalWS      : TEXCOORD3;
                    half3  tangentWS     : TEXCOORD4;
                    half3  bitangentWS   : TEXCOORD5;
                #else
                    half3  normalWS      : TEXCOORD3;
                #endif
                

                half3  viewDirWS     : TEXCOORD7;

                float4 shadowCoords  : TEXCOORD6;
            };

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceData.hlsl"

            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);

            #if _NORMALMAP

            TEXTURE2D(_NormalMap); SAMPLER(sampler_NormalMap);
            
            #endif
            
            
            Varyings PBRVertex(Attributes input)
            {
                Varyings o;

                VertexPositionInputs positionInputs = GetVertexPositionInputs(input.positionOS.xyz);

                #if _NORMALMAP
                    VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS.xyz,input.tangentOS);
                #else
                    VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS.xyz);
                #endif

                #if defined(_ALPHATEST_ON)
                    output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
                #endif
                
                o.positionCS = positionInputs.positionCS;
                o.positionWS = positionInputs.positionWS;

                half3 viewDir = GetWorldSpaceViewDir(positionInputs.positionWS);
                o.viewDirWS = viewDir;

                o.normalWS = normalInputs.normalWS;

                #if _NORMALMAP
                    o.tangentWS = normalInputs.tangentWS;
                    o.bitangentWS = normalInputs.bitangentWS;
                #endif
                
                
                OUTPUT_LIGHTMAP_UV(input.lighmapUV,unity_LightmapST,o.lightmapUV);
                OUTPUT_SH(o.normalWS,o.vertexSH);

                o.uv = TRANSFORM_TEX(input.uv,_MainTex);

                o.shadowCoords = GetShadowCoord(positionInputs);
                
                return o;
            }

            half4 PBRFragment(Varyings input) : SV_TARGET
            {
                
                half4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
                half4 baseColor = _BaseColor * texColor;
                

                InputData lightningInput = (InputData)0;
                lightningInput.positionWS = input.positionWS;
                lightningInput.normalWS = input.normalWS;
                lightningInput.viewDirectionWS = input.viewDirWS;
                lightningInput.shadowCoord = input.shadowCoords;

                
                SurfaceData surfaceData= (SurfaceData)0;
                surfaceData.albedo    = baseColor.rgb;

                #if _ALPHATEST_ON
                    surfaceData.alpha     = baseColor.a;
                #else
                    surfaceData.alpha = 1;
                    clip(baseColor.a - _AlphaClip);
                #endif
                
                surfaceData.metallic  = _Metalic;
                surfaceData.smoothness= _Smoothness;
                surfaceData.occlusion = _OcclusionMultiplier;
                surfaceData.emission  = _EmissionColor;
                
                
                #if _NORMALMAP
                    half3 normalTS = UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, input.uv)).xyz;
                    surfaceData.normalTS = TransformTangentToWorld(normalTS, input.tangentWS, input.bitangentWS, input.normalWS);
                #else
                    surfaceData.normalTS = input.normalWS;
                #endif

                return UniversalFragmentPBR(lightningInput,surfaceData);
            }
            
            ENDHLSL
        }
    }
}
