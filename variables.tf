variable "owner" {
  description = "Tag value naming who owns these resources."
  type        = string
  default     = "mohamed"
}

variable "alert_email" {
  description = "Where budget alerts are sent."
  type        = string
}
