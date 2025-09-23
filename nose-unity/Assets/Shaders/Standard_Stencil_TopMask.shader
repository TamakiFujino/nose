Shader "Nose/Standard Stencil (Top Mask)"
{
	Properties
	{
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo", 2D) = "white" {}
		_Glossiness ("Smoothness", Range(0,1)) = 0.5
		_Metallic ("Metallic", Range(0,1)) = 0.0
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" "Queue"="Geometry+1" }
		Cull Off
		LOD 200

		// Tops (inner clothing) test stencil so they are hidden where outer clothing (jacket) wrote stencil
		Stencil
		{
			Ref 1
			Comp NotEqual
			Pass Keep
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


