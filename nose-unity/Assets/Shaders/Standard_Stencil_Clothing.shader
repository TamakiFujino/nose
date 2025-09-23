Shader "Nose/Standard Stencil (Clothing)"
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
		Tags { "RenderType"="Opaque" "Queue"="Geometry" }
		Cull Off
		LOD 200

        // Clothing writes to stencil so underlying masked layers (e.g., Tops) can clip, but default Standard stays unaffected
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


