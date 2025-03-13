Shader "Shaders/ScreenPSX" {
	Properties {
		_MainTex ("Example Texture", 2D) = "white" {}
		_NoiseMap ("Example Texture", 2D) = "white" {}
		_BaseColor ("Example Colour", Color) = (0, 0.66, 0.73, 1)
		_PixelSize ("Pixel Size", Range(1, 100)) = 10
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
		float4 _MainTex_ST;
		float4 _NoiseMap_ST;
		float4 _BaseColor;
		half _PixelSize;
		//float4 _ExampleVector;
		//float _ExampleFloat;
		CBUFFER_END
		ENDHLSL

		Pass {
			Name "Unlit"
			//Tags { "LightMode"="SRPDefaultUnlit" } // (is default anyway)

			HLSLPROGRAM
			#pragma vertex UnlitPassVertex
			#pragma fragment UnlitPassFragment

			// Structs
			struct Attributes {
				float4 positionOS	: POSITION;
				float2 uv		: TEXCOORD0;
				float4 color		: COLOR;
			};

			struct Varyings {
				float4 positionCS 	: SV_POSITION;
				float2 uv		: TEXCOORD0;
				float4 color		: COLOR;
			};

			// Textures, Samplers & Global Properties
			TEXTURE2D(_MainTex);SAMPLER(sampler_MainTex);
			TEXTURE2D(_NoiseMap);SAMPLER(sampler_NoiseMap);

			// Vertex Shader
			Varyings UnlitPassVertex(Attributes IN) {
				Varyings OUT;

				VertexPositionInputs positionInputs = GetVertexPositionInputs(IN.positionOS.xyz);
				OUT.positionCS = positionInputs.positionCS;
				
				OUT.uv = TRANSFORM_TEX((floor(IN.uv*10)/10), _MainTex);
				OUT.color = IN.color;
				return OUT;
			}

			// Fragment Shader
			half4 UnlitPassFragment(Varyings IN) : SV_Target {
				
				// Tamaño del pixel en relación con la textura
                half2 pixelSize = _PixelSize / _ScreenParams.xy;

                // Redondeo de coordenadas UV para efecto pixelado
                half2 uv = floor(IN.uv / pixelSize) * pixelSize;
				
				half4 baseMap = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);

				half2 movingUV = sin(IN.uv+half2(_Time.y*100,0));
				half mask = SAMPLE_TEXTURE2D(_NoiseMap, sampler_NoiseMap, movingUV).r;
				
				mask = floor(mask*500)/500;
				baseMap = floor(baseMap*500)/500;
				
				return lerp(baseMap,baseMap*0.9,mask) * IN.color;
			}
			ENDHLSL
		}
	}
}
