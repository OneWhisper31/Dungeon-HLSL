Shader "Shaders/Fire Shader" {
	Properties {
		_MainTex ("Fire Texture", 2D) = "white" {}
		_Color1 ("White Color Mask", Color) = (1,1,1,1)
		_Color2 ("Black Color Mask", Color) = (0,0,0,1)
		_NoiseScale ("Noise Scale", Vector) = (5,5,0,0)
		_NoiseVelocity ("Noise Velocity", Float) = 5
		_NoiseStrength ("Noise Strength", Float) = 0.2
		_YScale ("Y Scale", Float) = 1
		_YPosStrength ("Y Pos Strength", Float) = 0.23
		_YPosAffect ("Y Pos Affect", Float) = -0.58
	}
	SubShader {
		Tags {
			"RenderPipeline"="UniversalPipeline"
			"RenderType"="Transparent"
			"Queue"="Transparent"
		}

		HLSLINCLUDE
		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

		CBUFFER_START(UnityPerMaterial)
		half4 _MainTex_ST;
		half3 _Color1;
		half3 _Color2;
		half2 _NoiseScale;
		half _NoiseVelocity;
		half _NoiseStrength;
		half _YScale;
		half _YPosStrength;
		half _YPosAffect;
		CBUFFER_END
		ENDHLSL

		Pass {
			Name "Unlit"

			Blend SrcAlpha OneMinusSrcAlpha

			HLSLPROGRAM
			#pragma vertex UnlitPassVertex
			#pragma fragment UnlitPassFragment

			#include "Assets/Materials/Shaders/Noise.hlsl"

			//unity
			#pragma multi_compile_fog

			// Structs
			struct Attributes {
				float4 positionOS	: POSITION;
				half2 uv		    : TEXCOORD0;
			};

			struct Varyings {
				float4 positionCS 	: SV_POSITION;
				half2 uv		    : TEXCOORD0;
				half4 positionOS	: TEXCOORD1;
				half  fogFactor		: TEXCOORD6;
			};

			// Textures, Samplers & Global Properties
			TEXTURE2D(_MainTex);
			SAMPLER(sampler_MainTex);

			// Vertex Shader
			Varyings UnlitPassVertex(Attributes IN) {
				Varyings OUT;

				VertexPositionInputs positionInputs = GetVertexPositionInputs(IN.positionOS.xyz);
				
				OUT.positionCS = positionInputs.positionCS;
				OUT.positionOS = IN.positionOS;
				
				OUT.uv = TRANSFORM_TEX(IN.uv, _MainTex);
				OUT.fogFactor = ComputeFogFactor(positionInputs.positionCS.z);
				
				return OUT;
			}

			// Fragment Shader
			half4 UnlitPassFragment(Varyings IN) : SV_Target {
				
				half2 uvTime = frac(IN.uv + half2(0,_Time.y*_NoiseVelocity*-1));
				half noise = (snoise(uvTime * _NoiseScale)-0.5)*_NoiseStrength;
				half2 noiseUV = IN.uv * half2(1,_YScale) + half2(0,noise);

				
				half smoothStep = smoothstep(_YPosAffect,_YPosStrength,IN.positionOS.y);
				

				half2 finalUV = lerp(IN.uv,noiseUV,smoothStep);
				
				half4 mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, finalUV);

				half mask = saturate(floor(mainTex.r * 20) / 20 + sin(_Time.y*20)*0.05);

				half4 color = half4(lerp(_Color1,_Color2,mask),mainTex.w);

				
				color.rgb = MixFog(color.rgb, IN.fogFactor);
				
				return color;
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

            #pragma multi_compile_instancing
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            //noise
            #include "Assets/Materials/Shaders/Noise.hlsl"

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
                float4 positionCS   : SV_POSITION;
                float2 uv       : TEXCOORD0;
            	half3 positionOS	: TEXCOORD1;
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

            	//half2 uvTime = frac(input.texcoord+half2(0,_Time.y *_NoiseVelocity*-1));
            	//half noise = (snoise(uvTime * _NoiseScale)-0.5)*_NoiseStrength;
            	//half2 noiseUV = input.texcoord * half2(1,_YScale) + half2(0,noise);
            	
            	
                output.uv = TRANSFORM_TEX(input.texcoord, _MainTex);
                
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
				output.positionOS = input.positionOS.xyz;
            	
                return output;
            }

            half4 ShadowPassFragment(Varyings IN) : SV_TARGET
            {
                UNITY_SETUP_INSTANCE_ID(IN);

                half2 uvTime = frac(IN.uv + half2(0,_Time.y*_NoiseVelocity*-1));
				half noise = (snoise(uvTime * _NoiseScale)-0.5)*_NoiseStrength;
				half2 noiseUV = IN.uv * half2(1,_YScale) + half2(0,noise);

				
				half smoothStep = smoothstep(_YPosAffect,_YPosStrength,IN.positionOS.y);
				

				half2 finalUV = lerp(IN.uv,noiseUV,smoothStep);
				
				half4 mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, finalUV);

				half mask = floor(mainTex.a * 20) / 20;
            	
                    clip(mask-0.5);

                return 0;
            }
            
            ENDHLSL
        }

       		// DepthOnly, used for Camera Depth Texture (if cannot copy depth buffer instead, and the DepthNormals below isn't used)
		Pass {
			Name "DepthOnly"
			Tags { "LightMode"="DepthOnly" }

			ColorMask 0
			ZWrite On
			ZTest LEqual

			HLSLPROGRAM
			#pragma vertex DepthOnlyVertex
			#pragma fragment DepthOnlyFragment

			// Material Keywords
			#pragma shader_feature _ALPHATEST_ON
			#pragma shader_feature _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

			// GPU Instancing
			#pragma multi_compile_instancing
			//#pragma multi_compile _ DOTS_INSTANCING_ON

			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"

			// Note if we do any vertex displacement, we'll need to change the vertex function. e.g. :
			/*
			#pragma vertex DisplacedDepthOnlyVertex (instead of DepthOnlyVertex above)
			
			Varyings DisplacedDepthOnlyVertex(Attributes input) {
				Varyings output = (Varyings)0;
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
				
				// Example Displacement
				input.positionOS += float4(0, _SinTime.y, 0, 0);
				
				output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
				output.positionCS = TransformObjectToHClip(input.position.xyz);
				return output;
			}
			*/
			
			ENDHLSL
		}
		Pass {
			Name "DepthNormals"
			Tags { "LightMode"="DepthNormals" }

			ZWrite On
			ZTest LEqual

			HLSLPROGRAM
			#pragma vertex DepthNormalsVertex
			#pragma fragment DepthNormalsFragment

			// Material Keywords
			#pragma shader_feature_local _NORMALMAP
			#pragma shader_feature _ALPHATEST_ON
			#pragma shader_feature _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

			// GPU Instancing
			#pragma multi_compile_instancing
			//#pragma multi_compile _ DOTS_INSTANCING_ON

			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Shaders/DepthNormalsPass.hlsl"

			// Note if we do any vertex displacement, we'll need to change the vertex function. e.g. :
			/*
			#pragma vertex DisplacedDepthNormalsVertex (instead of DepthNormalsVertex above)

			Varyings DisplacedDepthNormalsVertex(Attributes input) {
				Varyings output = (Varyings)0;
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
				
				// Example Displacement
				input.positionOS += float4(0, _SinTime.y, 0, 0);
				
				output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
				output.positionCS = TransformObjectToHClip(input.position.xyz);
				VertexNormalInputs normalInput = GetVertexNormalInputs(input.normal, input.tangentOS);
				output.normalWS = NormalizeNormalPerVertex(normalInput.normalWS);
				return output;
			}
			*/
			
			ENDHLSL
		}
	}
}