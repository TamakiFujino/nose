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
        Pass { }
    }
    Fallback Off
}


