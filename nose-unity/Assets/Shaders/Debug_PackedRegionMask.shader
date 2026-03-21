Shader "Nose/Debug Packed Region Mask"
{
    Properties
    {
        _RegionMaskPack0 ("Region Mask Pack 0 (1-4)", 2D) = "black" {}
        _RegionMaskPack1 ("Region Mask Pack 1 (5-8)", 2D) = "black" {}
        _RegionMaskPack2 ("Region Mask Pack 2 (9-12)", 2D) = "black" {}
        _RegionMaskPack3 ("Region Mask Pack 3 (13-16)", 2D) = "black" {}
        _Mode ("Debug Mode (0=Combined, 1=Target)", Range(0, 1)) = 0
        _TargetRegionId ("Target Region ID", Range(1, 14)) = 1
        _Threshold ("Threshold", Range(0.0, 1.0)) = 0.5
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "Queue" = "Geometry" }

        Pass
        {
            Name "DebugPackedRegionMaskURP"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            TEXTURE2D(_RegionMaskPack0);
            SAMPLER(sampler_RegionMaskPack0);
            TEXTURE2D(_RegionMaskPack1);
            SAMPLER(sampler_RegionMaskPack1);
            TEXTURE2D(_RegionMaskPack2);
            SAMPLER(sampler_RegionMaskPack2);
            TEXTURE2D(_RegionMaskPack3);
            SAMPLER(sampler_RegionMaskPack3);

            float4 _RegionMaskPack0_ST;
            float _Mode;
            float _TargetRegionId;
            float _Threshold;

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = TRANSFORM_TEX(IN.uv, _RegionMaskPack0);
                return OUT;
            }

            half ChannelForTarget(half4 p0, half4 p1, half4 p2, half4 p3, int target)
            {
                if (target == 1) return p0.r;
                if (target == 2) return p0.g;
                if (target == 3) return p0.b;
                if (target == 4) return p0.a;
                if (target == 5) return p1.r;
                if (target == 6) return p1.g;
                if (target == 7) return p1.b;
                if (target == 8) return p1.a;
                if (target == 9) return p2.r;
                if (target == 10) return p2.g;
                if (target == 11) return p2.b;
                if (target == 12) return p2.a;
                if (target == 13) return p3.r;
                if (target == 14) return p3.g;
                return 0.0h;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half4 p0 = SAMPLE_TEXTURE2D(_RegionMaskPack0, sampler_RegionMaskPack0, IN.uv);
                half4 p1 = SAMPLE_TEXTURE2D(_RegionMaskPack1, sampler_RegionMaskPack1, IN.uv);
                half4 p2 = SAMPLE_TEXTURE2D(_RegionMaskPack2, sampler_RegionMaskPack2, IN.uv);
                half4 p3 = SAMPLE_TEXTURE2D(_RegionMaskPack3, sampler_RegionMaskPack3, IN.uv);

                if (_Mode < 0.5)
                {
                    return saturate(p0 + p1 + p2 + p3);
                }

                int target = (int)round(_TargetRegionId);
                half v = ChannelForTarget(p0, p1, p2, p3, target);
                return v > _Threshold ? half4(1, 1, 1, 1) : half4(0.02, 0.02, 0.02, 1);
            }
            ENDHLSL
        }
    }
}
