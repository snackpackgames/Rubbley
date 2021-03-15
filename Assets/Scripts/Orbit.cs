using System;
using System.Collections.Generic;
using UnityEngine;

public class Orbit : MonoBehaviour
{
    public float orbitSpeed = default;
    public SphereCollider orbitTrigger = default;
    private float orbitRadius = default;

    private Rigidbody rbRef = default;

    private List<Attractor> orbitingChildren = new List<Attractor>();

    void Awake()
    {
        orbitRadius = orbitTrigger.radius;
        rbRef = GetComponentInParent<Rigidbody>();
    }

    void OnTriggerEnter(Collider other)
    {
        Debug.Log("Orbit trigger entered");

        Attractor otherAttractor = other.GetComponent<Attractor>();
        Rigidbody otherBody = other.GetComponent<Rigidbody>();

        if (CanTriggerOrbit(otherAttractor, otherBody))
        {
            otherBody.isKinematic = true;

            Vector3 relativePosition = otherAttractor.transform.position - transform.position;

            orbitingChildren.Add(otherAttractor);

            GameObject pivot = new GameObject(string.Format("Pivot For {0}", otherAttractor.name));

            pivot.transform.SetParent(transform);
            pivot.transform.localPosition = Vector3.zero;

            otherAttractor.transform.SetParent(pivot.transform);
            otherAttractor.transform.localPosition = relativePosition;
        }
    }

    bool CanTriggerOrbit(Attractor otherAttractor, Rigidbody otherBody)
    {
        return otherAttractor != null && otherBody != null && !otherBody.isKinematic && otherBody.mass < rbRef.mass;
    }

    void FixedUpdate()
    {
        foreach (Attractor child in orbitingChildren)
        {
            Transform pivot = child.GetComponent<Transform>().parent.transform;
            pivot.rotation = pivot.rotation * Quaternion.Euler(0, 0, 1 * orbitSpeed);
        }

    }
}
