Shader "Nose/Standard Stencil (Clothing)"
{
	Properties
	{
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo", 2D) = "white" {}
		_Glossiness ("Smoothness", Range(0,1)) = 0.5
		_Metallic ("Metallic", Range(0,1)) = 0.0
	}
	// URP SubShader
	SubShader
	{
		Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" "Queue"="Geometry" }
		Cull Back
		ZWrite On
		ZTest LEqual
		LOD 200

		Stencil
		{
			Ref 1
			Comp Always
			Pass Replace
		}

		Pass
		{
			Name "ForwardLit"
			Tags { "LightMode" = "UniversalForward" }
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 3.0
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

			TEXTURE2D(_MainTex);
			SAMPLER(sampler_MainTex);
			float4 _MainTex_ST;
			half4 _Color;
			half _Glossiness;
			half _Metallic;

			struct Attributes
			{
				float4 positionOS : POSITION;
				float3 normalOS : NORMAL;
				float2 uv : TEXCOORD0;
			};
			struct Varyings
			{
				float4 positionCS : SV_POSITION;
				float2 uv : TEXCOORD0;
				float3 normalWS : TEXCOORD1;
				float3 positionWS : TEXCOORD2;
			};

			Varyings vert(Attributes IN)
			{
				Varyings OUT;
				VertexPositionInputs posInputs = GetVertexPositionInputs(IN.positionOS.xyz);
				OUT.positionCS = posInputs.positionCS;
				OUT.positionWS = posInputs.positionWS;
				OUT.uv = TRANSFORM_TEX(IN.uv, _MainTex);
				OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);
				return OUT;
			}

			half4 frag(Varyings IN) : SV_Target
			{
				half4 c = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv) * _Color;

				InputData inputData = (InputData)0;
				inputData.positionWS = IN.positionWS;
				inputData.normalWS = normalize(IN.normalWS);
				inputData.viewDirectionWS = GetWorldSpaceNormalizeViewDir(IN.positionWS);
				inputData.shadowCoord = float4(0, 0, 0, 0);
				inputData.bakedGI = SampleSH(inputData.normalWS);
				inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(IN.positionCS);

				SurfaceData surfaceData = (SurfaceData)0;
				surfaceData.albedo = c.rgb;
				surfaceData.metallic = _Metallic;
				surfaceData.smoothness = _Glossiness;
				surfaceData.alpha = c.a;
				surfaceData.occlusion = 1.0h;

				return UniversalFragmentPBR(inputData, surfaceData);
			}
			ENDHLSL
		}
	}
	// Built-in RP fallback
    SubShader
	{
		Tags { "RenderType"="Opaque" "Queue"="Geometry" }
		Cull Back
		ZWrite On
		ZTest LEqual
		LOD 200

		Stencil
		{
			Ref 1
			Comp Always
			Pass Replace
		}

		CGPROGRAM
        #pragma surface surf Standard fullforwardshadows addshadow
		#pragma target 3.0

		sampler2D _MainTex;
		fixed4 _Color;
		half _Glossiness;
		half _Metallic;

		struct Input
		{
			float2 uv_MainTex;
		};

		void surf (Input IN, inout SurfaceOutputStandard o)
		{
			fixed4 c = tex2D(_MainTex, IN.uv_MainTex) * _Color;
			o.Albedo = c.rgb;
			o.Metallic = _Metallic;
			o.Smoothness = _Glossiness;
			o.Alpha = c.a;
		}
		ENDCG
	}
	Fallback "Diffuse"
}
