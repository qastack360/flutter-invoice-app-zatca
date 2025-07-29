import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface ZatcaWebhookPayload {
  uuid: string;
  status: string;
  timestamp: string;
  invoice_hash: string;
  qr_code?: string;
  error_message?: string;
  compliance_status?: string;
  reporting_status?: string;
  clearance_status?: string;
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Verify webhook signature (implement proper signature verification)
    const signature = req.headers.get('x-zatca-signature')
    const webhookSecret = Deno.env.get('ZATCA_WEBHOOK_SECRET')
    
    if (!verifyWebhookSignature(req, signature, webhookSecret)) {
      throw new Error('Invalid webhook signature')
    }

    // Parse webhook payload
    const payload: ZatcaWebhookPayload = await req.json()
    
    if (!payload.uuid || !payload.status) {
      throw new Error('Invalid webhook payload')
    }

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Update invoice status based on webhook
    await updateInvoiceStatus(supabase, payload)

    // Log webhook event
    await logWebhookEvent(supabase, payload)

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: 'Webhook processed successfully',
        timestamp: new Date().toISOString()
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )

  } catch (error) {
    console.error('Webhook processing error:', error)
    
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
        timestamp: new Date().toISOString(),
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      }
    )
  }
})

// Verify webhook signature
async function verifyWebhookSignature(req: Request, signature: string | null, secret: string | undefined): Promise<boolean> {
  if (!signature || !secret) {
    console.warn('Missing signature or secret, skipping verification')
    return true // Skip verification in development
  }

  // In production, implement proper HMAC signature verification
  // For now, we'll do a simple check
  try {
    // Clone the request to read body
    const clonedReq = req.clone()
    const body = await clonedReq.text()
    
    // Create expected signature
    const encoder = new TextEncoder()
    const key = encoder.encode(secret)
    const message = encoder.encode(body)
    
    // Use Web Crypto API for HMAC
    const cryptoKey = await crypto.subtle.importKey(
      'raw',
      key,
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['sign']
    )
    
    const signatureBuffer = await crypto.subtle.sign('HMAC', cryptoKey, message)
    const expectedSignature = Array.from(new Uint8Array(signatureBuffer))
      .map(b => b.toString(16).padStart(2, '0'))
      .join('')
    
    return signature === expectedSignature
  } catch (error) {
    console.error('Signature verification error:', error)
    return false
  }
}

// Update invoice status based on webhook payload
async function updateInvoiceStatus(supabase: any, payload: ZatcaWebhookPayload) {
  try {
    const { uuid, status, qr_code, error_message, compliance_status, reporting_status, clearance_status } = payload

    // Determine sync status based on ZATCA status
    let syncStatus = 'pending'
    let zatcaResponse: any = {
      uuid,
      status,
      timestamp: payload.timestamp,
      compliance_status,
      reporting_status,
      clearance_status,
    }

    if (status === 'approved' || status === 'cleared') {
      syncStatus = 'completed'
      if (qr_code) {
        zatcaResponse.qr_code = qr_code
      }
    } else if (status === 'rejected' || status === 'failed') {
      syncStatus = 'failed'
      if (error_message) {
        zatcaResponse.error_message = error_message
      }
    } else if (status === 'processing') {
      syncStatus = 'in_progress'
    }

    // Update invoices table
    const { error: invoiceError } = await supabase
      .from('invoices')
      .update({
        sync_status: syncStatus,
        zatca_uuid: uuid,
        zatca_qr_code: qr_code,
        zatca_response: zatcaResponse,
        updated_at: new Date().toISOString(),
      })
      .eq('zatca_uuid', uuid)

    if (invoiceError) {
      console.error('Error updating invoice:', invoiceError)
    }

    // Update sync_tracking table
    const { error: trackingError } = await supabase
      .from('sync_tracking')
      .update({
        sync_status: syncStatus,
        zatca_uuid: uuid,
        zatca_qr_code: qr_code,
        zatca_response: zatcaResponse,
        sync_timestamp: new Date().toISOString(),
        error_message: error_message,
        updated_at: new Date().toISOString(),
      })
      .eq('zatca_uuid', uuid)

    if (trackingError) {
      console.error('Error updating sync tracking:', trackingError)
    }

    console.log(`Updated invoice ${uuid} with status: ${syncStatus}`)

  } catch (error) {
    console.error('Error updating invoice status:', error)
    throw error
  }
}

// Log webhook event for audit trail
async function logWebhookEvent(supabase: any, payload: ZatcaWebhookPayload) {
  try {
    const { error } = await supabase
      .from('sync_logs')
      .insert({
        action: 'zatca_webhook',
        status: payload.status,
        details: JSON.stringify(payload),
        timestamp: new Date().toISOString(),
        invoice_id: payload.uuid,
        request_id: `webhook_${Date.now()}`,
      })

    if (error) {
      console.error('Error logging webhook event:', error)
    }

  } catch (error) {
    console.error('Error logging webhook event:', error)
  }
}

// Handle different webhook event types
async function handleWebhookEvent(supabase: any, payload: ZatcaWebhookPayload) {
  const eventType = payload.status

  switch (eventType) {
    case 'compliance_approved':
      await handleComplianceApproved(supabase, payload)
      break
    case 'compliance_rejected':
      await handleComplianceRejected(supabase, payload)
      break
    case 'reporting_submitted':
      await handleReportingSubmitted(supabase, payload)
      break
    case 'reporting_failed':
      await handleReportingFailed(supabase, payload)
      break
    case 'clearance_approved':
      await handleClearanceApproved(supabase, payload)
      break
    case 'clearance_rejected':
      await handleClearanceRejected(supabase, payload)
      break
    default:
      console.log(`Unknown webhook event type: ${eventType}`)
  }
}

// Handle compliance approval
async function handleComplianceApproved(supabase: any, payload: ZatcaWebhookPayload) {
  console.log(`Compliance approved for invoice ${payload.uuid}`)
  
  // Update status to indicate compliance approval
  await updateInvoiceStatus(supabase, {
    ...payload,
    status: 'compliance_approved'
  })
}

// Handle compliance rejection
async function handleComplianceRejected(supabase: any, payload: ZatcaWebhookPayload) {
  console.log(`Compliance rejected for invoice ${payload.uuid}: ${payload.error_message}`)
  
  // Update status to indicate compliance rejection
  await updateInvoiceStatus(supabase, {
    ...payload,
    status: 'compliance_rejected'
  })
}

// Handle reporting submission
async function handleReportingSubmitted(supabase: any, payload: ZatcaWebhookPayload) {
  console.log(`Reporting submitted for invoice ${payload.uuid}`)
  
  // Update status to indicate reporting submission
  await updateInvoiceStatus(supabase, {
    ...payload,
    status: 'reporting_submitted'
  })
}

// Handle reporting failure
async function handleReportingFailed(supabase: any, payload: ZatcaWebhookPayload) {
  console.log(`Reporting failed for invoice ${payload.uuid}: ${payload.error_message}`)
  
  // Update status to indicate reporting failure
  await updateInvoiceStatus(supabase, {
    ...payload,
    status: 'reporting_failed'
  })
}

// Handle clearance approval
async function handleClearanceApproved(supabase: any, payload: ZatcaWebhookPayload) {
  console.log(`Clearance approved for invoice ${payload.uuid}`)
  
  // Update status to indicate clearance approval
  await updateInvoiceStatus(supabase, {
    ...payload,
    status: 'clearance_approved'
  })
}

// Handle clearance rejection
async function handleClearanceRejected(supabase: any, payload: ZatcaWebhookPayload) {
  console.log(`Clearance rejected for invoice ${payload.uuid}: ${payload.error_message}`)
  
  // Update status to indicate clearance rejection
  await updateInvoiceStatus(supabase, {
    ...payload,
    status: 'clearance_rejected'
  })
} 