Shader "Nose/Body Region Mask"
{
	Properties
	{
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo", 2D) = "white" {}
		_Glossiness ("Smoothness", Range(0,1)) = 0.5
		_Metallic ("Metallic", Range(0,1)) = 0.0
		_RegionHideMask ("Region Hide Mask (bits)", Int) = 0
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 200

		CGPROGRAM
		#pragma surface surf Standard fullforwardshadows addshadow
		#pragma multi_compile __ FORCE_OPAQUE_ALPHA
		#pragma target 3.0

		sampler2D _MainTex;
		fixed4 _Color;
		half _Glossiness;
		half _Metallic;
		int _RegionHideMask;

		struct Input
		{
			float2 uv_MainTex;
			float4 color : COLOR; // vertex color encodes region id in .r as 0..1 → 0..255
		};

		void surf (Input IN, inout SurfaceOutputStandard o)
		{
			// Decode region id from vertex color R channel (0..255)
			int regionId = (int)round(saturate(IN.color.r) * 255.0);
			if (((1 << regionId) & _RegionHideMask) != 0)
			{
				clip(-1); // discard pixel for hidden region
			}
			fixed4 c = tex2D(_MainTex, IN.uv_MainTex) * _Color;
			o.Albedo = c.rgb;
			o.Metallic = _Metallic;
			o.Smoothness = _Glossiness;
			#ifdef FORCE_OPAQUE_ALPHA
			o.Alpha = 1.0;
			#else
			o.Alpha = c.a;
			#endif
		}
		ENDCG
	}
	Fallback "Diffuse"
}



