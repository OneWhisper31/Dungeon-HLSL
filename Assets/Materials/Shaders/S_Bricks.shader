// Example Shader for Universal RP
// Written by @Cyanilux
// https://www.cyanilux.com/tutorials/urp-shader-code

/*
Roughly equivalent to the URP/SimpleLit.shader (but Forward path only)
https://github.com/Unity-Technologies/Graphics/blob/master/Packages/com.unity.render-pipelines.universal/Shaders/SimpleLit.shader
*/

Shader "Shaders/Bricks" {
	Properties {
		
		[MainTexture] _BaseMap ("Example Texture", 2D) = "white" {}
		_NoiseTexture ("Noise Texture", 2D) = "white" {}
		_NoiseColor ("Noise Color", Color) = (0.5,0.5,0.5,1)
		_NoiseIntensity ("Noise Intensity", Range(0,1)) = 0.5
		_NoiseScale ("Noise Scale",Float) = 1
		_MainTexScale ("Noise Scale",Float) = 1
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
		half4 _BaseMap_ST;
		half4 _NoiseTexture_ST;
		half4 _NoiseColor;
		half _NoiseIntensity;
		half _NoiseScale;
		half _MainTexScale;
		CBUFFER_END
		ENDHLSL

		Pass {
			Name "ForwardLit"
			Tags { "LightMode"="UniversalForward" }

			HLSLPROGRAM
			#pragma vertex LitPassVertex
			#pragma fragment LitPassFragment

			// Material Keywords
			#pragma shader_feature_local_fragment _EMISSION
			#pragma shader_feature_local _RECEIVE_SHADOWS_OFF
			//#pragma shader_feature_local_fragment _SURFACE_TYPE_TRANSPARENT
			#pragma shader_feature_local_fragment _ALPHATEST_ON
			#pragma shader_feature_local_fragment _ALPHAPREMULTIPLY_ON
			//#pragma shader_feature_local_fragment _ _SPECGLOSSMAP _SPECULAR_COLOR
			#pragma shader_feature_local_fragment _ _SPECGLOSSMAP
			#define _SPECULAR_COLOR // always on
			#pragma shader_feature_local_fragment _GLOSSINESS_FROM_BASE_ALPHA

			// URP Keywords
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
			// Note, v11 changes this to :
			// #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN

			#pragma multi_compile _ _SHADOWS_SOFT
			#pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
			#pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
			#pragma multi_compile _ LIGHTMAP_SHADOW_MIXING // v10+ only, renamed from "_MIXED_LIGHTING_SUBTRACTIVE"
			#pragma multi_compile _ SHADOWS_SHADOWMASK // v10+ only

			// Unity Keywords
			#pragma multi_compile _ LIGHTMAP_ON
			#pragma multi_compile _ DIRLIGHTMAP_COMBINED
			#pragma multi_compile_fog

			// GPU Instancing (not supported)
			//#pragma multi_compile_instancing

			// Includes
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"

			// Structs
			struct Attributes {
				float4 positionOS	: POSITION;
				float4 normalOS		: NORMAL;
				float2 uv		    : TEXCOORD0;
				float2 lightmapUV	: TEXCOORD1;
				float4 color		: COLOR;
				//UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct Varyings {
				float4 positionCS 					: SV_POSITION;
				float2 uv		    				: TEXCOORD0;
				DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 1);
				half3 normalWS					: TEXCOORD3;
				
				#ifdef _ADDITIONAL_LIGHTS_VERTEX
					half4 fogFactorAndVertexLight	: TEXCOORD6; // x: fogFactor, yzw: vertex light
				#else
					half  fogFactor					: TEXCOORD6;
				#endif

				#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
					float4 shadowCoord 				: TEXCOORD7;
				#endif

				float4 color						: COLOR;
				//UNITY_VERTEX_INPUT_INSTANCE_ID
				//UNITY_VERTEX_OUTPUT_STEREO
			};

			// Textures, Samplers & Global Properties
			TEXTURE2D(_NoiseTexture);SAMPLER(sampler_NoiseTexture);

			// Functions
			half4 SampleSpecularSmoothness(float2 uv, half alpha, half4 specColor, TEXTURE2D_PARAM(specMap, sampler_specMap)) {
				half4 specularSmoothness = half4(0.0h, 0.0h, 0.0h, 1.0h);
				#ifdef _SPECGLOSSMAP
					specularSmoothness = SAMPLE_TEXTURE2D(specMap, sampler_specMap, uv) * specColor;
				#elif defined(_SPECULAR_COLOR)
					specularSmoothness = specColor;
				#endif

				#if UNITY_VERSION >= 202120 // or #if SHADER_LIBRARY_VERSION_MAJOR < 12, but that versioning method is deprecated for newer versions
					// v12 is changing this, so it's calculated later. Likely so that smoothness value stays 0-1 so it can display better for debug views.
					#ifdef _GLOSSINESS_FROM_BASE_ALPHA
						specularSmoothness.a = exp2(10 * alpha + 1);
					#else
						specularSmoothness.a = exp2(10 * specularSmoothness.a + 1);
					#endif
				#endif
				return specularSmoothness;
			}

			//  SurfaceData & InputData
			void InitalizeSurfaceData(Varyings IN, out SurfaceData surfaceData){
				surfaceData = (SurfaceData)0; // avoids "not completely initalized" errors

				half4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv);
				half noiseMap = SAMPLE_TEXTURE2D(_NoiseTexture, sampler_NoiseTexture, IN.uv*_NoiseScale).r;

				half4 diffuse = lerp(baseMap,_NoiseColor,noiseMap*_NoiseIntensity) * IN.color;
				surfaceData.albedo = diffuse.rgb;
				surfaceData.normalTS = SampleNormal(IN.uv, TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap));
				//surfaceData.emission = SampleEmission(IN.uv, _EmissionColor.rgb, TEXTURE2D_ARGS(_EmissionMap, sampler_EmissionMap));
				surfaceData.occlusion = 1.0; // unused
			}

			void InitializeInputData(Varyings input, out InputData inputData) {
				inputData = (InputData)0; // avoids "not completely initalized" errors

				

				
				half3 viewDirWS = GetWorldSpaceNormalizeViewDir(inputData.positionWS);
				inputData.normalWS = input.normalWS;

				inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);

				viewDirWS = SafeNormalize(viewDirWS);
				inputData.viewDirectionWS = viewDirWS;

				#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
					inputData.shadowCoord = input.shadowCoord;
				#elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
					inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
				#else
					inputData.shadowCoord = float4(0, 0, 0, 0);
				#endif

				// Fog
				#ifdef _ADDITIONAL_LIGHTS_VERTEX
					inputData.fogCoord = input.fogFactorAndVertexLight.x;
					inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;
				#else
					inputData.fogCoord = input.fogFactor;
					inputData.vertexLighting = half3(0, 0, 0);
				#endif
				
				inputData.bakedGI = SAMPLE_GI(input.lightmapUV, input.vertexSH, inputData.normalWS);
				inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
				inputData.shadowMask = SAMPLE_SHADOWMASK(input.lightmapUV);
			}

			// Vertex Shader
			Varyings LitPassVertex(Attributes IN) {
				Varyings OUT;

				//UNITY_SETUP_INSTANCE_ID(IN);
				//UNITY_TRANSFER_INSTANCE_ID(IN, OUT);
				//UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);

				VertexPositionInputs positionInputs = GetVertexPositionInputs(IN.positionOS.xyz);
				VertexNormalInputs normalInputs = GetVertexNormalInputs(IN.normalOS.xyz);

				OUT.positionCS = positionInputs.positionCS;

				half3 viewDirWS = GetWorldSpaceViewDir(positionInputs.positionWS);
				half3 vertexLight = VertexLighting(positionInputs.positionWS, normalInputs.normalWS);
				half fogFactor = ComputeFogFactor(positionInputs.positionCS.z);
				
				OUT.normalWS = NormalizeNormalPerVertex(normalInputs.normalWS);

				OUTPUT_LIGHTMAP_UV(IN.lightmapUV, unity_LightmapST, OUT.lightmapUV);
				OUTPUT_SH(OUT.normalWS.xyz, OUT.vertexSH);

				#ifdef _ADDITIONAL_LIGHTS_VERTEX
					OUT.fogFactorAndVertexLight = half4(fogFactor, vertexLight);
				#else
					OUT.fogFactor = fogFactor;
				#endif

				#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
					OUT.shadowCoord = GetShadowCoord(positionInputs);
				#endif

				OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
				OUT.color = IN.color;
				return OUT;
			}

			// Fragment Shader
			half4 LitPassFragment(Varyings IN) : SV_Target {
				//UNITY_SETUP_INSTANCE_ID(IN);
				//UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);

				// Setup SurfaceData
				SurfaceData surfaceData;
				InitalizeSurfaceData(IN, surfaceData);

				// Setup InputData
				InputData inputData;
				InitializeInputData(IN, inputData);

				// Simple Lighting (Lambert & BlinnPhong)
				//half4 color = UniversalFragmentBlinnPhong(inputData, surfaceData); // v12 only
				half4 color = UniversalFragmentBlinnPhong(inputData, surfaceData);
				// See Lighting.hlsl to see how this is implemented.
				// https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl

				color.rgb = MixFog(color.rgb, inputData.fogCoord);
				//color.a = OutputAlpha(color.a, _Surface);
				return color;
			}
			ENDHLSL
		}

		// UsePass "Universal Render Pipeline/Lit/ShadowCaster"
		// UsePass "Universal Render Pipeline/Lit/DepthOnly"
		// Would be nice if we could just use the passes from existing shaders,
		// However this breaks SRP Batcher compatibility. Instead, we should define them :

		// ShadowCaster, for casting shadows
		Pass {
			Name "ShadowCaster"
			Tags { "LightMode"="ShadowCaster" }

			ZWrite On
			ZTest LEqual

			HLSLPROGRAM
			#pragma vertex ShadowPassVertex
			#pragma fragment ShadowPassFragment

			// Material Keywords
			#pragma shader_feature_local_fragment _ALPHATEST_ON
			#pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

			// GPU Instancing
			#pragma multi_compile_instancing
			//#pragma multi_compile _ DOTS_INSTANCING_ON

			// Universal Pipeline Keywords
			// (v11+) This is used during shadow map generation to differentiate between directional and punctual (point/spot) light shadows, as they use different formulas to apply Normal Bias
			#pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"

			// Note if we do any vertex displacement, we'll need to change the vertex function. e.g. :
			/*
			#pragma vertex DisplacedShadowPassVertex (instead of ShadowPassVertex above)
			
			Varyings DisplacedShadowPassVertex(Attributes input) {
				Varyings output = (Varyings)0;
				UNITY_SETUP_INSTANCE_ID(input);
				
				// Example Displacement
				input.positionOS += float4(0, _SinTime.y, 0, 0);
				
				output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
				output.positionCS = GetShadowPositionHClip(input);
				return output;
			}
			*/
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
			#pragma shader_feature_local_fragment _ALPHATEST_ON
			#pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

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

		// DepthNormals, used for SSAO & other custom renderer features that request it
		Pass {
			Name "DepthNormals"
			Tags { "LightMode"="DepthNormals" }

			ZWrite On
			ZTest LEqual

			HLSLPROGRAM
			#pragma vertex DepthNormalsVertex
			#pragma fragment DepthNormalsFragment

			// Material Keywords
			
			#pragma shader_feature_local_fragment _ALPHATEST_ON
			#pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

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
