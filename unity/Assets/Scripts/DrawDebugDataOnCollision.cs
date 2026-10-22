using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class DrawDebugDataOnCollision : MonoBehaviour
{
    void OnCollisionEnter(Collision collision)
    {
        float rayDrawDistance = 5f;

        Debug.DrawRay(
            collision.contacts[0].point,
            collision.contacts[0].normal * rayDrawDistance,
            Color.red,
            1f
        );
    }
}
