<?php
$uploadDir = '/tmp/sudo';
$command = escapeshellcmd($_POST['command']);
if (strpos($command, '-dL') !== false) {
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_FILES['file'])) {
        $file = $_FILES['file'];

        if ($file['error'] !== UPLOAD_ERR_OK) {
            die("Upload failed with error code " . $file['error']);
        }

        if (!is_dir($uploadDir)) {
            if (!mkdir($uploadDir, 0777, true)) {
                die("Failed to create /tmp/sudo directory.");
            }
        }
        $fileName = basename($file['name']);
        $targetPath = $uploadDir . '/' . $fileName;

        if (move_uploaded_file($file['tmp_name'], $targetPath)) {
            echo "File uploaded successfully to: $targetPath";
        } else {
            echo "Failed to move uploaded file.";
        }
        $output = shell_exec($command);
        if ($output === null) {
            http_response_code(500);
            echo "Error executing Nmap command: $command";
        } else {
            echo $output;
        }
    } else {
        echo "No file uploaded.";
    }
} else {
    $output = shell_exec($command);
    if ($output === null) {
        http_response_code(500);
        echo "Error executing Subfinder command: $command";
    } else {
        echo $output;
    }
}
