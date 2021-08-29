using UnityEngine;

public class CreateGravityWell : MonoBehaviour
{
    public GameObject gravityWellPrefab;
    public Camera referenceCamera;

    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        if (Input.GetMouseButtonDown(0)) {
            HandleMouseButtonDown();
        }
    }

    void HandleMouseButtonDown() {
        Vector3 position = new Vector3(Input.mousePosition.x, Input.mousePosition.y, referenceCamera.nearClipPlane);

        Vector3 worldPosition = referenceCamera.ScreenToWorldPoint(position);

        Instantiate(gravityWellPrefab, worldPosition, Quaternion.identity);
    }
}
