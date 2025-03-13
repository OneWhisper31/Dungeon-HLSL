Shader "Unlit/S_DiffuseLightShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Color ("Color", Color) = (1,1,1,0)
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
                    
        }
        
        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        
        CBUFFER_START(UnityPerMaterial)

            half4 _MainTex_ST;
            half4 _Color;
        
        CBUFFER_END
        ENDHLSL
        
        Pass {
            
            Name "ForwardLit"
            
            Tags
            {
                "LightMode" = "UniversalForward"
            }
            HLSLPROGRAM

            #pragma vertex DiffuseVertex
            #pragma fragment DiffuseFragment

            //URP KEYWORDS
            //MAIN LIGHT KEYWORDS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN

            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHTS_SHADOWS
            #pragma multi_compile _ _MIXED_LIGHTNING_SUBTRACTIVE
            #pragma multi_compile _ SHADOWS_MASK

            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile_fog

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            
            struct Atributtes
            {
                float4 positionOS : POSITION;
                float4 normalOS   : NORMAL;
                half2  uv         : TEXCOORD0;
                half2 lightmapUV  : TEXCOORD1;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                half2  uv         : TEXCOORD0;
                DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 1);
                float3 positionWS : TEXCOORD2;
                float3 normalWS   : TEXCOORD3;
            };

            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);

            Varyings DiffuseVertex(Atributtes input)
            {
                Varyings o;

                VertexPositionInputs positionInputs = GetVertexPositionInputs(input.positionOS.xyz);
                o.positionCS = positionInputs.positionCS;
                o.positionWS = positionInputs.positionWS;

                VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS.xyz);
                o.normalWS = normalInputs.normalWS;

                OUTPUT_LIGHTMAP_UV(input.lightmapUV,unity_LightmapST,o.lightmapUV);
                OUTPUT_SH(o.normalWS,o.vertexSH);
                
                o.uv = TRANSFORM_TEX(input.uv,_MainTex);

                return o;
            }

            half4 DiffuseFragment(Varyings input) : SV_TARGET{

                half3 color = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,input.uv).rgb;
                

                half3 bakedGI = SAMPLE_GI(input.lightmapUV,input.vertexSH,input.normalWS);

                float4 shadowCoordinates = TransformWorldToShadowCoord(input.positionWS);
                Light mainLight = GetMainLight(shadowCoordinates);
                half3 attenuatedLightColor = mainLight.color * (mainLight.distanceAttenuation * mainLight.shadowAttenuation);

                MixRealtimeAndBakedGI(mainLight,input.normalWS,bakedGI);

                half3 shading = bakedGI + LightingLambert(attenuatedLightColor, mainLight.direction,input.normalWS);

                color *= shading * _Color.rgb;
                
                return  half4(color,1);
            }
            
            ENDHLSL
        }
        Pass
        {
            Name "ShadowCaster"
            Tags
            {
                "LightMode" = "ShadowCaster"
            }
            
            ZWrite On
            ZTest LEqual
            
            HLSLPROGRAM

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #pragma multi_compile_instancing
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            
            ENDHLSL
        }
        Pass
        {
            Name "DepthOnly"
            Tags
            {
                "LightMode" = "DepthOnly"
            }
            
            ZWrite On
            ZTest LEqual
            
            HLSLPROGRAM

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            #pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            
            ENDHLSL
        }
        Pass
        {
            Name "DepthNormals"
            Tags
            {
                "LightMode" = "DepthNormals"
            }
            
            ZWrite On
            ZTest LEqual
            
            HLSLPROGRAM

            #pragma vertex DepthNormalsVertex
            #pragma fragment DepthNormalsFragment

            #pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthNormalsPass.hlsl"
            
            ENDHLSL
        }
    }
}
