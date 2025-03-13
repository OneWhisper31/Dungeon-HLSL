Shader "Unlit/S_Transparent"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Color ("Color", Color) = (1,0,0,1)
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Transparent"
            "Queue" = "Transparent"
        }
        
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        CBUFFER_START(UnityPerMaterial)
            half4 _MainTex_ST;
            half4 _Color;
        CBUFFER_END
        ENDHLSL

        Pass
        {
            Name "Transparent"
            
            Blend SrcAlpha OneMinusSrcAlpha
            
            HLSLPROGRAM

            #pragma vertex TransparentVertex
            #pragma fragment TransparentFragment

            struct Atributtes
            {
                float4 positionOS : POSITION;
                half2  uv         : TEXCOORD0;

                half4 color       : COLOR;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                half2  uv         : TEXCOORD0;

                half4 color       : TEXCOORD1;
            };

            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);

            Varyings TransparentVertex(Atributtes input)
            {
                Varyings o;

                VertexPositionInputs positionInputs = GetVertexPositionInputs(input.positionOS.xyz);
                o.positionCS = positionInputs.positionCS;
                o.color = input.color;
                o.uv = TRANSFORM_TEX(input.uv,_MainTex);

                return o;
            }

            half4 TransparentFragment(Varyings input) : SV_TARGET{

                half4 color = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,input.uv);
                color = color   * _Color * input.color;

                return  color;
            }
            
            ENDHLSL
        }
    }
}
