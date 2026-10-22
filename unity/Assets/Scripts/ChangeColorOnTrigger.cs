using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ChangeColorOnTrigger : MonoBehaviour
{
    private Renderer cachedRenderer;

    void Awake()
    {
        cachedRenderer = GetComponent<Renderer>();
    }

    public void OnTriggerEnter(Collider other)
    {
        Color randomColor = GetRandomColorWithAlpha(0.25f);
        cachedRenderer.material.color = randomColor;
    } 

    Color GetRandomColorWithAlpha(float alpha) {
        return new Color(
            UnityEngine.Random.Range(0f, 1f),
            UnityEngine.Random.Range(0f, 1f),
            UnityEngine.Random.Range(0f, 1f),
            alpha
        );
    }
}
