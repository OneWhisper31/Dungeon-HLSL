using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Player : MonoBehaviour
{
    [SerializeField] private float sensitivity;
    [SerializeField] private float speed;

    private Camera mainCamera;

    private Rigidbody rb;

    private Vector2 rotationInputs;

    private bool visible;
    
    // Start is called before the first frame update
    void Start()
    {
        rb = GetComponent<Rigidbody>();
        mainCamera = GetComponentInChildren<Camera>();

        DisableCursor();
    }

    private void Update()
    {
        if (Input.GetKeyDown(KeyCode.Escape))
        {
            if (visible)
                DisableCursor();
            else
                EnableCursor();
            visible = !visible;
        }
        
        rotationInputs += new Vector2( Input.GetAxis("Mouse X"), Input.GetAxis("Mouse Y"))* sensitivity;
        rotationInputs.y = Mathf.Clamp(rotationInputs.y, -80, 80);

        var xQuat = Quaternion.AngleAxis(rotationInputs.x, Vector3.up);
        var yQuat = Quaternion.AngleAxis(rotationInputs.y, Vector3.left);

        mainCamera.transform.localRotation = xQuat * yQuat;
    }
    void EnableCursor()
    {
        Cursor.lockState = CursorLockMode.None;
        Cursor.visible = true;
    }
    void DisableCursor()
    {
        Cursor.lockState = CursorLockMode.Locked;
        Cursor.visible = false;
    }

    private void FixedUpdate()
    {
        Vector3 forward = Camera.main.transform.TransformDirection(Vector3.forward);
        Vector3 right = Camera.main.transform.TransformDirection(Vector3.right);
        
        Vector3 movement = right*Input.GetAxis("Horizontal")+ forward* Input.GetAxis("Vertical");
        rb.velocity = speed * Time.fixedDeltaTime * movement.normalized;
    }
}
