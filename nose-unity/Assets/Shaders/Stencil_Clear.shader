Shader "Nose/Stencil Clear"
{
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Background" }
        ZWrite Off
        ZTest Always
        ColorMask 0
        Stencil
        {
            Ref 0
            Comp Always
            Pass Replace
        }
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            float4 vert(uint id : SV_VertexID) : SV_POSITION
            {
                // Full-screen triangle from vertex ID
                float2 uv = float2((id << 1) & 2, id & 2);
                return float4(uv * 2.0 - 1.0, 0.0, 1.0);
            }
            half4 frag() : SV_Target { return 0; }
            ENDHLSL
        }
    }
    Fallback Off
}
