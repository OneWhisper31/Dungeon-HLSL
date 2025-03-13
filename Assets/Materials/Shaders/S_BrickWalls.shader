// Example Shader for Universal RP
// Written by @Cyanilux
// https://www.cyanilux.com/tutorials/urp-shader-code

/*
Note : URP v12 (2021.3+) added a Depth Priming option :
https://docs.unity3d.com/Packages/com.unity.render-pipelines.universal@12.1/manual/whats-new/urp-whats-new.html#depth-prepass-depth-priming-mode
This may be auto/enabled in the URP project templates and as a result, this shader may appear invisible.
Use the Unlit+ Template instead with the DepthOnly and DepthNormals passes to fix this.
*/

Shader "Shaders/BrickWallNoise" {
	Properties {
		_MainTex ("Example Texture", 2D) = "white" {}
		_NoiseTexture ("Noise Texture", 2D) = "white" {}
		_NoiseColor ("Noise Color", Color) = (0.5,0.5,0.5,1)
		_NoiseIntensity ("Noise Intensity", Range(0,1)) = 0.5
		_NoiseScale ("Noise Scale",Float) = 1
	}
	SubShader {
		Tags {
			"RenderPipeline"="UniversalPipeline"
			"RenderType"="Opaque"
			"Queue"="Geometry"
		}

		HLSLINCLUDE
		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

		CBUFFER_START(UnityPerMaterial)
		half4 _MainTex_ST;
		half4 _NoiseTexture_ST;
		half4 _NoiseColor;
		half _NoiseIntensity;
		half _NoiseScale;
		CBUFFER_END
		ENDHLSL

		Pass {
			Name "Unlit"

			HLSLPROGRAM
			#pragma vertex UnlitPassVertex
			#pragma fragment UnlitPassFragment

			// Structs
			struct Attributes {
				float4 positionOS	: POSITION;
				half2  uv		    : TEXCOORD0;
			};

			struct Varyings {
				half4 positionCS 	: SV_POSITION;
				half2 uv		    : TEXCOORD0;
				half2 positionWS	: TEXCOORD1;
			};

			// Textures, Samplers & Global Properties
			TEXTURE2D(_MainTex);SAMPLER(sampler_MainTex);
			TEXTURE2D(_NoiseTexture);SAMPLER(sampler_NoiseTexture);

			// Vertex Shader
			Varyings UnlitPassVertex(Attributes IN) {
				Varyings OUT;

				VertexPositionInputs positionInputs = GetVertexPositionInputs(IN.positionOS.xyz);
				OUT.positionCS = positionInputs.positionCS;
				OUT.positionWS = positionInputs.positionWS.xz;
				OUT.positionWS = OUT.positionWS + positionInputs.positionWS.yz;
				OUT.uv = TRANSFORM_TEX(IN.uv, _MainTex);
				return OUT;
			}

			// Fragment Shader
			half4 UnlitPassFragment(Varyings IN) : SV_Target {
				half4 baseMap = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv);
				half noiseMap = SAMPLE_TEXTURE2D(_NoiseTexture, sampler_NoiseTexture, IN.positionWS*_NoiseScale).r;
				return lerp(baseMap,_NoiseColor,noiseMap*_NoiseIntensity);
			}
			ENDHLSL
		}
	}
}
