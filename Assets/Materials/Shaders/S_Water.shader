// Example Shader for Universal RP
// Written by @Cyanilux
// https://www.cyanilux.com/tutorials/urp-shader-code

Shader "Shaders/Water" {
	Properties {
		_BaseMap ("Example Texture", 2D) = "white" {}
		_Color1	 ("Example Colour", Color) = (1, 1, 1, 1)
		_Color2 ("Example Colour", Color) = (0,0,0,0)
		_GeoRes("Geometric Resolution", Float) = 40
		_ClipStrength("Clip Strength", Range(0.8,1)) = 0.98
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
		half4 _BaseMap_ST;
		half4 _Color1;
		half4 _Color2;
		half _GeoRes;
		half _ClipStrength;
		CBUFFER_END
		ENDHLSL

		Pass {
			Name "Unlit"

			Blend SrcAlpha OneMinusSrcAlpha

			HLSLPROGRAM
			#pragma vertex UnlitPassVertex
			#pragma fragment UnlitPassFragment

			// Structs
			struct Attributes {
				float4 positionOS	: POSITION;
				half2 uv		    : TEXCOORD0;
			};

			struct Varyings {
				float4 positionCS 				: SV_POSITION;
				half2 uv						: TEXCOORD0;
			};

			// Textures, Samplers & Global Properties
			TEXTURE2D(_BaseMap);
			SAMPLER(sampler_BaseMap);

			// Vertex Shader
			Varyings UnlitPassVertex(Attributes IN) {
				Varyings OUT;

				VertexPositionInputs positionInputs = GetVertexPositionInputs(IN.positionOS.xyz);
				
				float3 wp = floor(positionInputs.positionVS *_GeoRes/_GeoRes);

				float4 sp = TransformWViewToHClip(wp);
				OUT.positionCS = lerp(sp,positionInputs.positionCS,_ClipStrength);

				half2 uv = TRANSFORM_TEX(IN.uv, _BaseMap);
				OUT.uv = uv;

				//extra
                //OUT.uv = float3(uv * sp.w, sp.w);
				//OUT.positionCS = positionInputs.positionCS;				
				//OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
				
				return OUT;
			}

			// Fragment Shader
			half4 UnlitPassFragment(Varyings IN) : SV_Target {
				float2 movingUV = frac(IN.uv+float2(_Time.x/2,0));
				//movingUV = float2(IN.uv.x/ IN.uv.z, IN.uv.y ); extra
				half mask = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, movingUV).r;

				half4 color = lerp(_Color1,_Color2,mask);

				return color;
			}
			ENDHLSL
		}
	}
}