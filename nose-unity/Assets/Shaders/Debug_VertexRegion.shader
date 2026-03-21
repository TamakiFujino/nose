Shader "Nose/Debug Vertex Region"
{
    Properties
    {
        _Brightness ("Brightness", Range(0.1, 4.0)) = 1.0
        _Mode ("Debug Mode (0=Palette, 1=RawID, 2=Highlight)", Range(0, 2)) = 0
        _TargetRegionId ("Target Region ID", Range(0, 30)) = 1
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "Queue" = "Geometry" }
        Pass
        {
            Name "DebugVertexRegionURP"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            float _Brightness;
            float _Mode;
            float _TargetRegionId;

            struct Attributes
            {
                float4 positionOS : POSITION;
                float4 color : COLOR;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                nointerpolation float regionId : TEXCOORD0;
            };

            half3 RegionColor(int regionId)
            {
                if (regionId <= 0) return half3(0.02, 0.02, 0.02);

                half r = frac(regionId * 0.23h + 0.11h);
                half g = frac(regionId * 0.41h + 0.37h);
                half b = frac(regionId * 0.67h + 0.19h);
                return max(half3(r, g, b), half3(0.18, 0.18, 0.18));
            }

            half3 DebugColor(int regionId)
            {
                if (_Mode < 0.5)
                    return RegionColor(regionId);

                if (_Mode < 1.5)
                {
                    half raw = saturate(regionId / 30.0h);
                    return half3(raw, raw, raw);
                }

                return abs(regionId - (int)round(_TargetRegionId)) < 1 ? half3(1.0, 1.0, 1.0) : half3(0.03, 0.03, 0.03);
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.regionId = round(saturate(IN.color.r) * 255.0);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                int regionId = (int)IN.regionId;
                half3 c = DebugColor(regionId) * _Brightness;
                return half4(c, 1.0);
            }
            ENDHLSL
        }
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" }
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0
            #include "UnityCG.cginc"

            float _Brightness;
            float _Mode;
            float _TargetRegionId;

            struct appdata
            {
                float4 vertex : POSITION;
                float4 color : COLOR;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                nointerpolation float regionId : TEXCOORD0;
            };

            fixed3 RegionColor(int regionId)
            {
                if (regionId <= 0) return fixed3(0.02, 0.02, 0.02);

                fixed r = frac(regionId * 0.23 + 0.11);
                fixed g = frac(regionId * 0.41 + 0.37);
                fixed b = frac(regionId * 0.67 + 0.19);
                return max(fixed3(r, g, b), fixed3(0.18, 0.18, 0.18));
            }

            fixed3 DebugColor(int regionId)
            {
                if (_Mode < 0.5)
                    return RegionColor(regionId);

                if (_Mode < 1.5)
                {
                    fixed raw = saturate(regionId / 30.0);
                    return fixed3(raw, raw, raw);
                }

                return abs(regionId - (int)round(_TargetRegionId)) < 1 ? fixed3(1.0, 1.0, 1.0) : fixed3(0.03, 0.03, 0.03);
            }

            v2f vert(appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.regionId = round(saturate(v.color.r) * 255.0);
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                int regionId = (int)i.regionId;
                fixed3 c = DebugColor(regionId) * _Brightness;
                return fixed4(c, 1.0);
            }
            ENDCG
        }
    }
}
