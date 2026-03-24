Shader "Nose/Capture Opaque"
{
	Properties
	{
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo", 2D) = "white" {}
	}
	// URP SubShader
	SubShader
	{
		Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" "Queue"="Geometry" }
		LOD 100

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
				surfaceData.metallic = 0;
				surfaceData.smoothness = 0;
				surfaceData.alpha = 1.0; // force fully opaque writes
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
		LOD 100

		CGPROGRAM
		#pragma surface surf Standard fullforwardshadows
		#pragma target 3.0

		sampler2D _MainTex;
		fixed4 _Color;

		struct Input
		{
			float2 uv_MainTex;
		};

		void surf(Input IN, inout SurfaceOutputStandard o)
		{
			fixed4 c = tex2D(_MainTex, IN.uv_MainTex) * _Color;
			o.Albedo = c.rgb;
			o.Metallic = 0;
			o.Smoothness = 0;
			o.Alpha = 1.0; // force fully opaque writes
		}
		ENDCG
	}
	Fallback "Diffuse"
}
