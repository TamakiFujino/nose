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
        // Use custom vertex function to compute a non-interpolated region id
        #pragma surface surf Standard fullforwardshadows addshadow vertex:vert
		#pragma multi_compile __ FORCE_OPAQUE_ALPHA
		#pragma target 3.0

		sampler2D _MainTex;
		fixed4 _Color;
		half _Glossiness;
		half _Metallic;
		int _RegionHideMask;

        // Input to surf; receive a non-interpolated region id to avoid seam artifacts
        struct Input
        {
            float2 uv_MainTex;
            nointerpolation float regionId; // computed per-vertex, not interpolated
        };

        void vert(inout appdata_full v, out Input o)
        {
            UNITY_INITIALIZE_OUTPUT(Input, o);
            o.uv_MainTex = v.texcoord.xy;
            // Decode integer region id from vertex color.r (0..1 → 0..255)
            o.regionId = round(saturate(v.color.r) * 255.0);
        }

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            // Use the non-interpolated region id to avoid thin lines at boundaries
            int regionId = (int)IN.regionId;
            // Treat region 0 as "never hide" to avoid accidental masking of head/hands/feet
            if (regionId > 0 && (((1 << regionId) & _RegionHideMask) != 0))
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



