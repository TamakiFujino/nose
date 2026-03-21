Shader "Nose/Body Region Mask"
{
	Properties
	{
		_Color ("Color", Color) = (1,1,1,1)
		[Toggle] _UseAlbedoTexture ("Use Albedo Texture", Float) = 0
		_MainTex ("Albedo", 2D) = "white" {}
		[Toggle] _UseRegionMaskTextures ("Use Region Mask Textures", Float) = 0
		_RegionMaskPack0 ("Region Mask Pack 0 (1-4)", 2D) = "black" {}
		_RegionMaskPack1 ("Region Mask Pack 1 (5-8)", 2D) = "black" {}
		_RegionMaskPack2 ("Region Mask Pack 2 (9-12)", 2D) = "black" {}
		_RegionMaskPack3 ("Region Mask Pack 3 (13-16)", 2D) = "black" {}
		_RegionMaskThreshold ("Region Mask Threshold", Range(0.0, 1.0)) = 0.5
		_Glossiness ("Smoothness", Range(0,1)) = 0.5
		_Metallic ("Metallic", Range(0,1)) = 0.0
		_RegionHideMask ("Region Hide Mask (bits)", Int) = 0
	}
	// URP: use this when project uses Universal RP (stops pink/magenta)
	SubShader
	{
		Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "Queue" = "Geometry" }
		LOD 200
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
			TEXTURE2D(_RegionMaskPack0);
			SAMPLER(sampler_RegionMaskPack0);
			TEXTURE2D(_RegionMaskPack1);
			SAMPLER(sampler_RegionMaskPack1);
			TEXTURE2D(_RegionMaskPack2);
			SAMPLER(sampler_RegionMaskPack2);
			TEXTURE2D(_RegionMaskPack3);
			SAMPLER(sampler_RegionMaskPack3);
			float4 _MainTex_ST;
			float4 _RegionMaskPack0_ST;
			half4 _Color;
			float _UseAlbedoTexture;
			float _UseRegionMaskTextures;
			float _RegionMaskThreshold;
			float _RegionHideMask;

			struct Attributes
			{
				float4 positionOS : POSITION;
				float3 normalOS : NORMAL;
				float2 uv : TEXCOORD0;
				float4 color : COLOR;
			};
			struct Varyings
			{
				float4 positionCS : SV_POSITION;
				float2 uv : TEXCOORD0;
				float3 normalWS : TEXCOORD1;
				float regionValue : TEXCOORD2;
			};

			Varyings vert(Attributes IN)
			{
				Varyings OUT;
				OUT.positionCS = TransformObjectToHClip(IN.positionOS.xyz);
				OUT.uv = TRANSFORM_TEX(IN.uv, _MainTex);
				OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);
				OUT.regionValue = saturate(IN.color.r);
				return OUT;
			}

			half IsRegionHidden(float regionId, float mask)
			{
				if (regionId <= 0.5) return 0.0h;
				float roundedRegion = floor(regionId + 0.5);
				float roundedMask = floor(mask + 0.5);
				float bitValue = floor(roundedMask / exp2(roundedRegion));
				return fmod(bitValue, 2.0) >= 0.5 ? 1.0h : 0.0h;
			}

			half HiddenByPackedMasks(float2 uv)
			{
				half4 pack0 = SAMPLE_TEXTURE2D(_RegionMaskPack0, sampler_RegionMaskPack0, uv);
				half4 pack1 = SAMPLE_TEXTURE2D(_RegionMaskPack1, sampler_RegionMaskPack1, uv);
				half4 pack2 = SAMPLE_TEXTURE2D(_RegionMaskPack2, sampler_RegionMaskPack2, uv);
				half4 pack3 = SAMPLE_TEXTURE2D(_RegionMaskPack3, sampler_RegionMaskPack3, uv);

				if (pack0.r > _RegionMaskThreshold && IsRegionHidden(1.0, _RegionHideMask) > 0.5h) return 1.0h;
				if (pack0.g > _RegionMaskThreshold && IsRegionHidden(2.0, _RegionHideMask) > 0.5h) return 1.0h;
				if (pack0.b > _RegionMaskThreshold && IsRegionHidden(3.0, _RegionHideMask) > 0.5h) return 1.0h;
				if (pack0.a > _RegionMaskThreshold && IsRegionHidden(4.0, _RegionHideMask) > 0.5h) return 1.0h;

				if (pack1.r > _RegionMaskThreshold && IsRegionHidden(5.0, _RegionHideMask) > 0.5h) return 1.0h;
				if (pack1.g > _RegionMaskThreshold && IsRegionHidden(6.0, _RegionHideMask) > 0.5h) return 1.0h;
				if (pack1.b > _RegionMaskThreshold && IsRegionHidden(7.0, _RegionHideMask) > 0.5h) return 1.0h;
				if (pack1.a > _RegionMaskThreshold && IsRegionHidden(8.0, _RegionHideMask) > 0.5h) return 1.0h;

				if (pack2.r > _RegionMaskThreshold && IsRegionHidden(9.0, _RegionHideMask) > 0.5h) return 1.0h;
				if (pack2.g > _RegionMaskThreshold && IsRegionHidden(10.0, _RegionHideMask) > 0.5h) return 1.0h;
				if (pack2.b > _RegionMaskThreshold && IsRegionHidden(11.0, _RegionHideMask) > 0.5h) return 1.0h;
				if (pack2.a > _RegionMaskThreshold && IsRegionHidden(12.0, _RegionHideMask) > 0.5h) return 1.0h;

				if (pack3.r > _RegionMaskThreshold && IsRegionHidden(13.0, _RegionHideMask) > 0.5h) return 1.0h;
				if (pack3.g > _RegionMaskThreshold && IsRegionHidden(14.0, _RegionHideMask) > 0.5h) return 1.0h;
				return 0.0h;
			}

			half4 frag(Varyings IN) : SV_Target
			{
				float2 regionMaskUv = TRANSFORM_TEX(IN.uv, _RegionMaskPack0);
				if (_UseRegionMaskTextures > 0.5)
				{
					if (HiddenByPackedMasks(regionMaskUv) > 0.5h)
						discard;
				}
				else
				{
					float regionId = round(saturate(IN.regionValue) * 255.0);
					if (IsRegionHidden(regionId, _RegionHideMask) > 0.5h)
						discard;
				}
				half4 c = _UseAlbedoTexture > 0 ? SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv) * _Color : _Color;

				half3 normalWS = normalize(IN.normalWS);
				Light mainLight = GetMainLight();
				half ndotl = saturate(dot(normalWS, mainLight.direction));
				half3 ambient = c.rgb * 0.35h;
				half3 diffuse = c.rgb * mainLight.color * ndotl;

				return half4(ambient + diffuse, c.a);
			}
			ENDHLSL
		}
	}
	// Built-in RP (legacy)
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
		sampler2D _RegionMaskPack0;
		sampler2D _RegionMaskPack1;
		sampler2D _RegionMaskPack2;
		sampler2D _RegionMaskPack3;
		float _UseAlbedoTexture;
		float _UseRegionMaskTextures;
		float _RegionMaskThreshold;
		fixed4 _Color;
		half _Glossiness;
		half _Metallic;
		float _RegionHideMask;
		float4 _RegionMaskPack0_ST;

        // Input to surf; receive interpolated region value to smooth boundaries
        struct Input
        {
            float2 uv_MainTex;
            float regionValue;
        };

        void vert(inout appdata_full v, out Input o)
        {
            UNITY_INITIALIZE_OUTPUT(Input, o);
            o.uv_MainTex = v.texcoord.xy;
            o.regionValue = saturate(v.color.r);
        }

        half IsRegionHidden(float regionId, float mask)
        {
            if (regionId <= 0.5) return 0.0h;
            float roundedRegion = floor(regionId + 0.5);
            float roundedMask = floor(mask + 0.5);
            float bitValue = floor(roundedMask / exp2(roundedRegion));
            return fmod(bitValue, 2.0) >= 0.5 ? 1.0h : 0.0h;
        }

        half HiddenByPackedMasks(float2 uv)
        {
            half4 pack0 = tex2D(_RegionMaskPack0, uv);
            half4 pack1 = tex2D(_RegionMaskPack1, uv);
            half4 pack2 = tex2D(_RegionMaskPack2, uv);
            half4 pack3 = tex2D(_RegionMaskPack3, uv);

            if (pack0.r > _RegionMaskThreshold && IsRegionHidden(1.0, _RegionHideMask) > 0.5h) return 1.0h;
            if (pack0.g > _RegionMaskThreshold && IsRegionHidden(2.0, _RegionHideMask) > 0.5h) return 1.0h;
            if (pack0.b > _RegionMaskThreshold && IsRegionHidden(3.0, _RegionHideMask) > 0.5h) return 1.0h;
            if (pack0.a > _RegionMaskThreshold && IsRegionHidden(4.0, _RegionHideMask) > 0.5h) return 1.0h;

            if (pack1.r > _RegionMaskThreshold && IsRegionHidden(5.0, _RegionHideMask) > 0.5h) return 1.0h;
            if (pack1.g > _RegionMaskThreshold && IsRegionHidden(6.0, _RegionHideMask) > 0.5h) return 1.0h;
            if (pack1.b > _RegionMaskThreshold && IsRegionHidden(7.0, _RegionHideMask) > 0.5h) return 1.0h;
            if (pack1.a > _RegionMaskThreshold && IsRegionHidden(8.0, _RegionHideMask) > 0.5h) return 1.0h;

            if (pack2.r > _RegionMaskThreshold && IsRegionHidden(9.0, _RegionHideMask) > 0.5h) return 1.0h;
            if (pack2.g > _RegionMaskThreshold && IsRegionHidden(10.0, _RegionHideMask) > 0.5h) return 1.0h;
            if (pack2.b > _RegionMaskThreshold && IsRegionHidden(11.0, _RegionHideMask) > 0.5h) return 1.0h;
            if (pack2.a > _RegionMaskThreshold && IsRegionHidden(12.0, _RegionHideMask) > 0.5h) return 1.0h;

            if (pack3.r > _RegionMaskThreshold && IsRegionHidden(13.0, _RegionHideMask) > 0.5h) return 1.0h;
            if (pack3.g > _RegionMaskThreshold && IsRegionHidden(14.0, _RegionHideMask) > 0.5h) return 1.0h;
            return 0.0h;
        }

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            float2 regionMaskUv = TRANSFORM_TEX(IN.uv_MainTex, _RegionMaskPack0);
            if (_UseRegionMaskTextures > 0.5)
            {
                if (HiddenByPackedMasks(regionMaskUv) > 0.5h)
                {
                    clip(-1);
                }
            }
            else
            {
                float regionId = round(saturate(IN.regionValue) * 255.0);
                if (IsRegionHidden(regionId, _RegionHideMask) > 0.5h)
			    {
				    clip(-1); // discard pixel for hidden region
			    }
            }
			fixed4 c = _UseAlbedoTexture > 0 ? tex2D(_MainTex, IN.uv_MainTex) * _Color : _Color;
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



