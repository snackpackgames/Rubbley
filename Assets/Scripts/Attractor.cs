// Adapted from https://github.com/Brackeys/Gravity-Simulation-Tutorial

using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Attractor : MonoBehaviour
{
    public const float G = 66.74f;
    public Rigidbody body;
    public Rigidbody gravigaTarget;
    public float gravigaMultiplier = 1.0f;

    void FixedUpdate()
    {
        Attractor[] attractors = FindObjectsOfType<Attractor>();
        foreach (Attractor attractor in attractors)
        {
            if (this != attractor)
            {
                if (gravigaTarget == attractor.body)
                {
                    Attract(attractor, gravigaMultiplier);
                }
                else
                {
                    Attract(attractor);
                }
            }
        }
    }

    void Attract(Attractor other, float currentGravigaMultipler = 1.0f)
    {
        Rigidbody otherBody = other.body;

        Vector3 direction = body.position - otherBody.position;
        float distance = direction.magnitude;

        Debug.Log(string.Format("distance: {0}", distance));

        float forceMagnitude = ((body.mass * otherBody.mass) / Mathf.Pow(distance, 2)) * G;

        Debug.Log(string.Format("forceMagnitude: {0}", forceMagnitude));
        Debug.Log(string.Format("gravigaMultiplier: {0}", gravigaMultiplier));

        Vector3 force = direction.normalized * (forceMagnitude * currentGravigaMultipler);

        Debug.Log(string.Format("force: ({0}, {1}, {2})", force.x, force.y, force.z));

        otherBody.AddForce(force);
    }
}
