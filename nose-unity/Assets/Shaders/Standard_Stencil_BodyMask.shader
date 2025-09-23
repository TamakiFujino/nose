Shader "Nose/Standard Stencil (Body Mask)"
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
		LOD 200

        // Body should not draw where clothing already wrote stencil = 1
        // but allow an override via material keyword _MASK_EXCLUDE to render normally (for hands/head)
		Stencil
		{
			Ref 1
			Comp NotEqual
			Pass Keep
		}

		CGPROGRAM
		#pragma surface surf Standard fullforwardshadows
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


