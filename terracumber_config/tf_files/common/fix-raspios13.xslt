<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="acpi"/>

  <xsl:template match="audio">
    <controller type="usb" index="0" model="qemu-xhci">
      <address type="pci" domain="0x0000" bus="0x00" slot="0x07" function="0x0"/>
    </controller>
    <input type="keyboard" bus="usb">
      <address type="usb" bus="0" port="1"/>
    </input>
    <input type="mouse" bus="usb">
      <address type="usb" bus="0" port="2"/>
    </input>
    <graphics type="vnc" autoport="yes">
      <listen type="address" address="0.0.0.0"/>
    </graphics>
    <video>
      <model type="virtio" vram="65536" heads="1" primary="yes"/>
      <address type="pci" domain="0x0000" bus="0x01" slot="0x00" function="0x0" multifunction="on"/>
    </video>
  </xsl:template>

</xsl:stylesheet>
