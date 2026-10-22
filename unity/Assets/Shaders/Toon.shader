Shader "Custom/Toon"
{
    Properties
    {
        _Color ("Color", Color) = (0.5, 0.65, 1, 1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        [HDR]
        _AmbientColor("Ambient Color", Color) = (0.4, 0.4, 0.4, 1)
        [HDR]
        _SpecularColor("Specular Color", Color) = (0.9, 0.9, 0.9, 1)
        _Glossiness("Glossiness", Float) = 32
        [HDR]
        _RimColor("Rim Color", Color) = (1,1,1,1)
        _RimAmount("Rim Amount", Range(0, 1)) = 0.716
        _RimThreshold("Rim Threshold", Range(0, 1)) = 0.1
    }
    SubShader
    {
		Pass
		{
            Tags
            {
                "LightMode" = "ForwardBase"
                "PassFlags" = "OnlyDirectional"
            }

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
            #pragma multi_compile_fwdbase
			
			#include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"

			struct appdata
			{
				float4 vertex : POSITION;				
				float4 uv : TEXCOORD0;
                float3 normal : NORMAL;
			};

			struct v2f
			{
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
                float3 worldNormal: NORMAL;
                float3 viewDir : TEXCOORD1;
                SHADOW_COORDS(2)
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			
			v2f vert (appdata v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.viewDir = WorldSpaceViewDir(v.vertex);
                TRANSFER_SHADOW(o)
				return o;
			}
			
			float4 _Color;
            float4 _AmbientColor;
            float4 _SpecularColor;
            float _Glossiness;
            float4 _RimColor;
            float _RimAmount;
            float _RimThreshold;

			float4 frag (v2f i) : SV_Target
			{
                // Sample the main texture for the base color of the surface
				float4 sample = tex2D(_MainTex, i.uv);

                // Get the normalized normal for the surface
                float3 normal = normalize(i.worldNormal);

                // Calculate the directional lighting intensity using the Blinn-Phong method
                // Dot product of the surface normal and the light source (_WorldSpaceLightPos0)
                // smoothed using smoothstep between (0, 0.01), multiplied by the current shadow attenuation

                float NdotL = dot(_WorldSpaceLightPos0, normal);
                float shadow = SHADOW_ATTENUATION(i);
                float lightIntensity = smoothstep(0, 0.01, NdotL * shadow);

                // Determine the intensity of specular reflection using Blinn-Phong method
                // Dot product of the surface normal and the half vector, which is calculated between
                // the viewing direction (v2f.viewDir) and the light source (_WorldSpaceLightPos0)
                // Determine the color of the specular reflection by smoothing the specular intensity and
                // by multiplying by the shader parameter (_SpecularColor)

                float3 viewDir = normalize(i.viewDir);
                float3 halfVector = normalize(_WorldSpaceLightPos0 + viewDir);
                float NdotH = dot(normal, halfVector);

                float specularIntensity = pow(NdotH * lightIntensity, _Glossiness * _Glossiness);
                float specularIntensitySmooth = smoothstep(0.005, 0.01, specularIntensity);
                float4 specular = specularIntensitySmooth * _SpecularColor;

                // Calculate rim lighting by inverting the dot product of the normal and view direction to determine
                // "rim" surfaces facing away from the camera
                // Multiply by the directional lighting to only rim light illuminated surfaces, and
                // use the shader parameter (_RimAmount) to smooth the rim intensity
                // as well as the other parameter (_RimThreshold) to determine
                // how far along the rim the lighting should extend

                float4 rimDot = 1 - dot(viewDir, normal);
                float rimIntensity = rimDot * pow(NdotL * lightIntensity, _RimThreshold);
                rimIntensity = smoothstep(_RimAmount - 0.01, _RimAmount + 0.01, rimIntensity);

                // Determine the color of the rim lighting by adding the shader parameter (_RimColor)

                float4 rim = rimIntensity * _RimColor;

                // Add ambient lighting by adding color from the light source (_LightColor0)
                // and the shader parameter (_AmbientColor)

                float4 light = lightIntensity * _LightColor0;

				return _Color * sample * (_AmbientColor + light + specular + rim);
			}
			ENDCG
		}
        UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"
    }
    FallBack "Diffuse"
}
