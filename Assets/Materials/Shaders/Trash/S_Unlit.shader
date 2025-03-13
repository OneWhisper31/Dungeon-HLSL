Shader "Unlit/S_Unlit"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _WhiteColor ("WhiteColor",Color) = (1,1,1,1)
        _BlackColor ("BlackColor",Color) = (0,0,0,0)
        _Intensity ("Color Intensity", Float) = 1
        _Min("Min Mask",Range(0,1)) = 0
        _Max("Max Mask",Range(0,1)) = 1
        _Speed("Max Mask",Vector) = (0,0,0,0)
        _MainTexIntensity("Texture Intensity",Range(0,1)) = 1
        [Toggle(_ALPHACLIP_ON)] _AlphaClip("Alpha Clip",Float) = 0
        _Clip("Clip",Range(0,1)) = 0.5
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
            "UniversalMaterialType" = "Lit" //Forward
        }
        
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        CBUFFER_START(UnityPerMaterial)
            half4 _MainTex_ST;
            half4 _WhiteColor;
            half4 _BlackColor;
            half2 _Speed;
            half _Intensity;
            half _Min;
            half _Max;
            half _Clip;
            half _MainTexIntensity;
        
        CBUFFER_END

        
        ENDHLSL

        Pass
        {
            Name "Unlit"
            Tags
            {
                "LightMode" = "SRPDefaultUnlit" //DEFAULT
            }
            HLSLPROGRAM

            #pragma vertex UnlitPassVertex
            #pragma fragment UnlitPassFragment

            #pragma shader_feature_fragment _ALPHACLIP_ON

            struct Attributes
            {
                float4 positionOS : POSITION;
                half2  uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                half2  uv         : TEXCOORD0;
            };

            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
            
            Varyings UnlitPassVertex(Attributes input)
            {
                Varyings o;

                float3 newPos = float3(0,sin(_Time.y) * 0.3,0);
                input.positionOS.xyz += newPos;
                o.positionCS = TransformObjectToHClip(input.positionOS.xyz);

                o.uv = TRANSFORM_TEX(input.uv, _MainTex);
                
                return  o;
            }
            
            half4 UnlitPassFragment(Varyings input) : SV_Target
            {
                half mask = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,input.uv + frac(_Time.yy*_Speed)).r;

                #if _ALPHACLIP_ON

                    clip(mask - _Clip);
                
                #endif
                
                
                mask = smoothstep(_Min,_Max,mask);
                half3 color = lerp(_BlackColor.rgb,_WhiteColor.rgb, mask);
                
                return half4(color,1);
            }
            
            ENDHLSL
        }
        Pass
        {
            Name "ShadowCaster"
            Tags {"LightMode" = "ShadowCaster"}
            
            ZWrite On
            ColorMask 0
            
            HLSLPROGRAM

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #pragma shader_feature _ALPHACLIP_ON

            #pragma multi_compile_instancing
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            // Shadow Casting Light geometric parameters. These variables are used when applying the shadow Normal Bias and are set by UnityEngine.Rendering.Universal.ShadowUtils.SetupShadowCasterConstantBuffer in com.unity.render-pipelines.universal/Runtime/ShadowUtils.cs
            // For Directional lights, _LightDirection is used when applying shadow Normal Bias.
            // For Spot lights and Point lights, _LightPosition is used to compute the actual light direction because it is different at each shadow caster geometry vertex.
            float3 _LightDirection;
            float3 _LightPosition;

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
                float2 texcoord     : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                #if defined(_ALPHACLIP_ON)
                    float2 uv       : TEXCOORD0;
                #endif
                float4 positionCS   : SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
            
            float4 GetShadowPositionHClip(Attributes input)
            {
                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                float3 normalWS = TransformObjectToWorldNormal(input.normalOS);

            #if _CASTING_PUNCTUAL_LIGHT_SHADOW
                float3 lightDirectionWS = normalize(_LightPosition - positionWS);
            #else
                float3 lightDirectionWS = _LightDirection;
            #endif

                float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));

            #if UNITY_REVERSED_Z
                positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE);
            #else
                positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE);
            #endif

                return positionCS;
            }

            Varyings ShadowPassVertex(Attributes input)
            {
                Varyings output;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);

                #if defined(_ALPHACLIP_ON)
                    output.uv = TRANSFORM_TEX(input.texcoord, _MainTex);
                #endif

                float3 newPos = float3(0,sin(_Time.y) * 0.3,0);
                
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz+newPos);
                
                return output;
            }

            half4 ShadowPassFragment(Varyings input) : SV_TARGET
            {
                UNITY_SETUP_INSTANCE_ID(input);

                
                #if defined(_ALPHACLIP_ON)
                    half mask = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,input.uv + frac(_Time.yy*_Speed)).r;
                    clip(mask-_Clip);
                #endif

                return 0;
            }
            
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            
            Tags
            {
                "LightMode" = "DepthOnly"
            }
            ColorMask 0
            ZWrite On
            ZTest LEqual
            
            HLSLPROGRAM

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment
            
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
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
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #if defined(LOD_FADE_CROSSFADE)
                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
            #endif
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RealtimeLights.hlsl"

            struct Attributes
            {
                float4 positionOS     : POSITION;
                float4 tangentOS      : TANGENT;
                float2 texcoord     : TEXCOORD0;
                float3 normal       : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS   : SV_POSITION;
                #if defined(_ALPHATEST_ON)
                    float2 uv       : TEXCOORD1;
                #endif
                float3 normalWS     : TEXCOORD2;

                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings DepthNormalsVertex(Attributes input)
            {
                Varyings output = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                #if defined(_ALPHATEST_ON)
                    output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
                #endif
                float3 newPos = float3(0,sin(_Time.y) * 0.3,0);
                input.positionOS.xyz += newPos;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);

                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normal, input.tangentOS);
                output.normalWS = NormalizeNormalPerVertex(normalInput.normalWS);

                return output;
            }

            void DepthNormalsFragment(
                Varyings input
                , out half4 outNormalWS : SV_Target0
            #ifdef _WRITE_RENDERING_LAYERS
                , out float4 outRenderingLayers : SV_Target1
            #endif
            )
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                #if defined(_ALPHATEST_ON)
                    Alpha(SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).a, _BaseColor, _Cutoff);
                #endif

                #if defined(LOD_FADE_CROSSFADE)
                    LODFadeCrossFade(input.positionCS);
                #endif

                #if defined(_GBUFFER_NORMALS_OCT)
                float3 normalWS = normalize(input.normalWS);
                float2 octNormalWS = PackNormalOctQuadEncode(normalWS);           // values between [-1, +1], must use fp32 on some platforms.
                float2 remappedOctNormalWS = saturate(octNormalWS * 0.5 + 0.5);   // values between [ 0,  1]
                half3 packedNormalWS = PackFloat2To888(remappedOctNormalWS);      // values between [ 0,  1]
                outNormalWS = half4(packedNormalWS, 0.0);
                #else
                float3 normalWS = NormalizeNormalPerPixel(input.normalWS);
                outNormalWS = half4(normalWS, 0.0);
                #endif

                #ifdef _WRITE_RENDERING_LAYERS
                    uint renderingLayers = GetMeshRenderingLayer();
                    outRenderingLayers = float4(EncodeMeshRenderingLayer(renderingLayers), 0, 0, 0);
                #endif
            }
            ENDHLSL
        }

    }
}
