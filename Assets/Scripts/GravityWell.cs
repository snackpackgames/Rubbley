using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class GravityWell : MonoBehaviour
{
    public const float G = 66.74f;
    public float massiveness = 1;
    Transform location;

    void FixedUpdate()
    {
        Attractor[] attractors = FindObjectsOfType<Attractor>();
        foreach (Attractor attractor in attractors)
        {
            if (this != attractor)
            {
                Attract(attractor);
            }
        }
    }

    void Attract(Attractor other, float currentGravigaMultipler = 1.0f)
    {
        Rigidbody otherBody = other.body;

        Vector3 direction = location.position - otherBody.position;
        float distance = direction.magnitude;

        Debug.Log(string.Format("distance: {0}", distance));

        float forceMagnitude = ((massiveness * otherBody.mass) / Mathf.Pow(distance, 2)) * G;

        Debug.Log(string.Format("forceMagnitude: {0}", forceMagnitude));

        Vector3 force = direction.normalized * (forceMagnitude * currentGravigaMultipler);

        Debug.Log(string.Format("force: ({0}, {1}, {2})", force.x, force.y, force.z));

        otherBody.AddForce(force);
    }
}
