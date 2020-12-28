using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Animations;

public class FollowCamera : MonoBehaviour {

	public Camera CameraReference;
	public GameObject Target;

	private LookAtConstraint _constraint;

	FollowCamera() { }

	// Use this for initialization
	void Start () {

		if (!Target) {
			return;
		}

		Camera followCamera = GetFollowCamera();

		if (!followCamera) {
			return;
		}

		InitializeConstraint();
	}
	
	// Update is called once per frame
	void Update () { }

	Camera GetFollowCamera() {
		if (!this.CameraReference) {
			this.CameraReference = Camera.main;
		}

		return this.CameraReference;
	}

	void InitializeConstraint() {
		this._constraint = this.CameraReference.gameObject.AddComponent<LookAtConstraint>();

		ConstraintSource targetSource = new ConstraintSource() {
			sourceTransform = Target.transform,
			weight = 1
		};

		this._constraint.AddSource(targetSource);
	}
}
