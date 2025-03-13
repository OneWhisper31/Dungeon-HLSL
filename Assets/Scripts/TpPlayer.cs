using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class TpPlayer : MonoBehaviour
{
   [SerializeField] private Collider otherPivot;
   
   bool teleporting = false;
   private void OnTriggerEnter(Collider other)
   {
      var pj = other.GetComponent<Player>();

      if (pj != null && teleporting == false)
         StartCoroutine(TeleportPlayer(pj));
   }

   IEnumerator TeleportPlayer(Player pj)
   {
      teleporting = true;
      
      otherPivot.enabled = false;
      
      float distance = pj.transform.position.z - transform.position.z;
      
      pj.transform.position = new Vector3(pj.transform.position.x, pj.transform.position.y, otherPivot.transform.position.z+distance);

      yield return new WaitForSeconds(0.4f);
      
      otherPivot.enabled = true;
      
      teleporting = false;
   }
}
